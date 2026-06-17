#!/usr/bin/env python3
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import sys
import os
import re

# --- Configuration using Command Line Arguments ---
if len(sys.argv) < 2:
    print("Usage: python3 plot.py <K_value>")
    print("Example: python3 plot.py 2")
    sys.exit(1)

try:
    K = int(sys.argv[1])
except ValueError:
    print("Error: K_value must be an integer.")
    sys.exit(1)

# File names
input_file = f"faststructure_K{K}.{K}.meanQ"
label_file = "../name_and_state_cleaned.txt"
output_pdf = f"Admixture_K{K}_State_Final_Order.jpg"

# --- 1. Read Q-matrix from .meanQ file ---
print(f"Reading Q-matrix from: {input_file} (K={K}).")

try:
    # Assuming fastStructure's meanQ files
    Q = pd.read_csv(input_file, sep='\s+', header=None)

    if Q.shape[1] != K:
        raise Exception(f"Expected {K} columns in Q-matrix but found {Q.shape[1]}. Check K value or file integrity.")

    print(f"Successfully read Q-data for {len(Q)} samples.")

except FileNotFoundError:
    print(f"Error: Input file not found: {input_file}")
    sys.exit(1)
except Exception as e:
    print(f"Error reading Q-matrix: {e}")
    sys.exit(1)


# ----------------------------------------------------------------------
# --- 2. Read Labels and Validate ---
# ----------------------------------------------------------------------
try:
    labels = [line.strip() for line in open(label_file)]

    if len(labels) != len(Q):
        print(f"Error: # of labels ({len(labels)}) does not match # of samples in Q-matrix ({len(Q)}). Cannot plot.")
        sys.exit(1)

except FileNotFoundError:
    print(f"Error: Label file not found: {label_file}")
    sys.exit(1)

# ----------------------------------------------------------------------
# --- 2.5 Grouping and Sorting Data (GEOGRAPHIC LOOP + NEBRASKA INTERNAL) ---
# ----------------------------------------------------------------------
print("Grouping and sorting samples by State (Final Geographic Order)...")

# FINAL GROUP_ORDER with underscores for multi-word states
GROUP_ORDER = [
    'Massachusetts', 'Maryland', 'Rhode_Island', # Northeast/Mid-Atlantic (Start)
    'Michigan', 'Wisconsin', 'Minnesota', 'Iowa', 'South_Dakota', # Upper Midwest
    'Nebraska', # Core Plains
    'Kansas', 'Oklahoma', 'Texas', # Plains/Southwest Transition
    'Tennessee', 'North_Carolina', 'South_Carolina', # Upper South/Appalachian
    'Virginia', # Virginia placement
    'Alabama', 'Florida', # Deep South (End)
    'Other'
]

# SECONDARY SORT KEY: Internal order for Nebraska samples
NEBRASKA_INTERNAL_ORDER = {
    'Win': 0,
    'FL': 1,
    'TR': 2,
    'Schram': 3,
    'CH': 4,
}


def get_group(label):
    """Function to extract the State name, handling multi-word names reliably."""

    parts = label.split('_')

    if len(parts) >= 2:
        last_part = parts[-1]
        second_to_last = parts[-2] if len(parts) >= 2 else ""

        # Handle two-word states with underscores
        if last_part == 'Carolina':
            if second_to_last == 'South':
                return 'South_Carolina'
            elif second_to_last == 'North':
                return 'North_Carolina'
        
        # Handle Rhode Island
        if last_part == 'Island' and second_to_last == 'Rhode':
            return 'Rhode_Island'
        
        # Handle South Dakota
        if last_part == 'Dakota' and second_to_last == 'South':
            return 'South_Dakota'

        # Handle single-word states
        if last_part in GROUP_ORDER:
            return last_part

    return 'Other'

def get_nebraska_internal_sort_key(label):
    """Assigns a numerical key to Nebraska samples based on prefix (Win, FL, TR, CH)."""
    if 'Nebraska' not in label:
        return 99 # Not Nebraska, send to the end of secondary sort

    # Check for the prefix (up to the first underscore)
    prefix = label.split('_')[0]

    # Check for Win, FL, TR, CH, and Schram prefixes
    if prefix.startswith('Win'): return NEBRASKA_INTERNAL_ORDER['Win']
    if prefix.startswith('FL'): return NEBRASKA_INTERNAL_ORDER['FL']
    if prefix.startswith('TR'): return NEBRASKA_INTERNAL_ORDER['TR']
    if prefix.startswith('CH'): return NEBRASKA_INTERNAL_ORDER['CH']
    if prefix.startswith('Schram'): return NEBRASKA_INTERNAL_ORDER['Schram']

    return 98 # Generic Nebraska sample, near the end

# 1. Create a DataFrame for labels and their assigned groups
sample_info = pd.DataFrame({
    'label': labels,
    'group': [get_group(l) for l in labels],
    'original_index': range(len(labels))
})

# 2. Assign primary (State) sort key
group_to_key = {group: i for i, group in enumerate(GROUP_ORDER)}
sample_info['primary_sort'] = sample_info['group'].map(group_to_key).fillna(len(GROUP_ORDER))

# 3. Assign secondary (Nebraska internal) sort key
sample_info['secondary_sort'] = sample_info['label'].apply(get_nebraska_internal_sort_key)

# 4. Sort the sample info DataFrame:
#    1. By State (primary_sort)
#    2. If State is Nebraska, by internal type (secondary_sort)
#    3. Finally, by the original label alphabetically
sample_info_sorted = sample_info.sort_values(
    by=['primary_sort', 'secondary_sort', 'label']
).reset_index(drop=True)


# 5. Reorder the Q-matrix and the labels list
new_indices = sample_info_sorted['original_index'].tolist()
Q = Q.iloc[new_indices, :]
labels = sample_info_sorted['label'].tolist()
groups_sorted = sample_info_sorted['group'].tolist()
print(f"Successfully grouped and reordered {len(Q)} samples.")

# ----------------------------------------------------------------------
# --- 3. Plotting the Stacked Bars (ULTRA WIDE, SCROLLABLE) ---
# ----------------------------------------------------------------------

# 1. Setup Figure - CUSTOM UNMC COLORS
# Define UNMC palette colors
unmc_palette = ['#AD122A', '#129DBF', '#F2672F', '#F0B614', '#656510', '#A1B42A', '#0D5E63', '#00B5D9', '#002D57']

# Use colors based on K value
if K <= len(unmc_palette):
    custom_colors = unmc_palette[:K]
else:
    # Fall back to tab10 if K exceeds available palette colors
    custom_colors = plt.cm.tab10.colors[:K]
    print(f"Warning: K={K} exceeds UNMC palette size. Using default colors.")

# Manual, large figure width for horizontal scrolling
fixed_width_inches = 45
fig, ax = plt.subplots(figsize=(fixed_width_inches, 6))
bottom = np.zeros(len(Q))

# 2. Plot Bars
for i in range(K):
    ax.bar(range(len(Q)), Q.iloc[:, i], bottom=bottom, color=custom_colors[i], width=1.0)
    bottom += Q.iloc[:, i]

# 3. Add Group Separation Lines and Labels
group_annotations = []
group_start_index = 0
current_group = groups_sorted[0]

for i in range(1, len(groups_sorted)):
    next_group = groups_sorted[i]

    if next_group != current_group:

        # A. Draw the separation line
        ax.axvline(x=i - 0.5, color='black', linestyle='-', linewidth=2.5, zorder=2)

        # B. Store the group label and its center
        group_end_index = i
        group_center = (group_start_index + group_end_index - 1) / 2

        # Replace underscores with spaces for display
        display_label = current_group.replace('_', ' ')
        group_annotations.append({'center': group_center, 'label': display_label})

        # Reset for the next group
        current_group = next_group
        group_start_index = i

# Process the last group
group_center = (group_start_index + len(groups_sorted) - 1) / 2
display_label = current_group.replace('_', ' ')
group_annotations.append({'center': group_center, 'label': display_label})


# 4. Draw the State Labels
for a in group_annotations:
    ax.text(
        a['center'],
        1.08,
        a['label'],
        ha='center',
        va='bottom',
        fontsize=9,
        fontweight='bold',
        transform=ax.get_xaxis_transform()
    )


# 5. Axis Configuration
ax.set_xticks(range(len(labels)))
# Ensure labels are legible with the generous spacing
ax.set_xticklabels(labels, rotation=90, fontsize=6, ha='right')

ax.set_ylabel("Ancestry Proportion", fontsize=10)
ax.set_xlabel("Samples (Sorted by Geographic Loop)", fontsize=10)
ax.set_title(f"Admixture Plot (K={K}) - Grouped by State", fontsize=12, y=1.18)
ax.set_xlim(-0.5, len(Q) - 0.5)
ax.set_ylim(0, 1.0)
ax.set_yticks([0, 0.25, 0.5, 0.75, 1.0])
ax.tick_params(axis='y', labelsize=8)

# Adjust bottom margin
plt.subplots_adjust(bottom=0.25)

# Save the ultra-wide PDF
plt.savefig(output_pdf, bbox_inches="tight", dpi=300, format='jpg')
print(f"✅ State Grouped Plot saved to {output_pdf}")
