#!/usr/bin/env python3
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import sys
import os
import re

# --- Configuration using Command Line Arguments ---
if len(sys.argv) < 2:
    print("Usage: python3 plot_horizontal_consistent.py <K_value>")
    print("Example: python3 plot_horizontal_consistent.py 2")
    sys.exit(1)

try:
    K = int(sys.argv[1])
except ValueError:
    print("Error: K_value must be an integer.")
    sys.exit(1)

# File names
input_file = f"faststructure_K{K}.{K}.meanQ"
label_file = "../name_and_state_cleaned.txt"
output_pdf = f"fastSTRUCTURE_K{K}_State_Horizontal.jpg"

# --- 1. Read Q-matrix from .meanQ file ---
print(f"Reading Q-matrix from: {input_file} (K={K}).")

try:
    Q = pd.read_csv(input_file, sep=r'\s+', header=None)

    if Q.shape[1] != K:
        raise Exception(f"Expected {K} columns in Q-matrix but found {Q.shape[1]}. Check K value or file integrity.")

    print(f"Successfully read Q-data for {len(Q)} samples.")

except FileNotFoundError:
    print(f"Error: Input file not found: {input_file}")
    sys.exit(1)
except Exception as e:
    print(f"Error reading Q-matrix: {e}")
    sys.exit(1)


# --- 2. Read Labels and Validate ---
try:
    labels = [line.strip() for line in open(label_file)]

    if len(labels) != len(Q):
        print(f"Error: # of labels ({len(labels)}) does not match # of samples in Q-matrix ({len(Q)}). Cannot plot.")
        sys.exit(1)

except FileNotFoundError:
    print(f"Error: Label file not found: {label_file}")
    sys.exit(1)

# --- 2.5 Grouping and Sorting Data ---
print("Grouping and sorting samples by State...")

GROUP_ORDER = [
    'Massachusetts', 'Maryland', 'Rhode_Island',
    'Michigan', 'Wisconsin', 'Minnesota', 'Iowa', 'South_Dakota',
    'Nebraska',
    'Kansas', 'Oklahoma', 'Texas',
    'Tennessee', 'North_Carolina', 'South_Carolina',
    'Virginia',
    'Alabama', 'Florida',
    'Other'
]

# State abbreviations mapping
STATE_ABBREV = {
    'Massachusetts': 'MA',
    'Maryland': 'MD',
    'Rhode_Island': 'RI',
    'Michigan': 'MI',
    'Wisconsin': 'WI',
    'Minnesota': 'MN',
    'Iowa': 'IA',
    'South_Dakota': 'SD',
    'Nebraska': 'NE',
    'Kansas': 'KS',
    'Oklahoma': 'OK',
    'Texas': 'TX',
    'Tennessee': 'TN',
    'North_Carolina': 'NC',
    'South_Carolina': 'SC',
    'Virginia': 'VA',
    'Alabama': 'AL',
    'Florida': 'FL',
    'Other': 'Other'
}

NEBRASKA_INTERNAL_ORDER = {
    'Win': 0,
    'FL': 1,
    'TR': 2,
    'Schram': 3,
    'CH': 4,
}

def get_group(label):
    parts = label.split('_')
    if len(parts) >= 2:
        last_part = parts[-1]
        second_to_last = parts[-2] if len(parts) >= 2 else ""

        if last_part == 'Carolina':
            if second_to_last == 'South': return 'South_Carolina'
            elif second_to_last == 'North': return 'North_Carolina'
        if last_part == 'Island' and second_to_last == 'Rhode': return 'Rhode_Island'
        if last_part == 'Dakota' and second_to_last == 'South': return 'South_Dakota'
        if last_part in GROUP_ORDER: return last_part
    return 'Other'

def get_nebraska_internal_sort_key(label):
    if 'Nebraska' not in label: return 99
    prefix = label.split('_')[0]
    if prefix.startswith('Win'): return NEBRASKA_INTERNAL_ORDER['Win']
    if prefix.startswith('FL'): return NEBRASKA_INTERNAL_ORDER['FL']
    if prefix.startswith('TR'): return NEBRASKA_INTERNAL_ORDER['TR']
    if prefix.startswith('CH'): return NEBRASKA_INTERNAL_ORDER['CH']
    if prefix.startswith('Schram'): return NEBRASKA_INTERNAL_ORDER['Schram']
    return 98

sample_info = pd.DataFrame({
    'label': labels,
    'group': [get_group(l) for l in labels],
    'original_index': range(len(labels))
})

group_to_key = {group: i for i, group in enumerate(GROUP_ORDER)}
sample_info['primary_sort'] = sample_info['group'].map(group_to_key).fillna(len(GROUP_ORDER))
sample_info['secondary_sort'] = sample_info['label'].apply(get_nebraska_internal_sort_key)

sample_info_sorted = sample_info.sort_values(
    by=['primary_sort', 'secondary_sort', 'label']
).reset_index(drop=True)

new_indices = sample_info_sorted['original_index'].tolist()
Q = Q.iloc[new_indices, :]
labels = sample_info_sorted['label'].tolist()
groups_sorted = sample_info_sorted['group'].tolist()
print(f"Successfully grouped and reordered {len(Q)} samples.")

# --- 2.6 Consistent Column Ordering Based on K=2 Reference ---
# Column order determined by correlation analysis with K=2

if K == 2:
    # K=2: col0 = Northern (Green), col1 = Southern (Purple)
    # Keep original order
    col_order = [0, 1]
    print(f"K=2 column order: {col_order} (Northern/Green, Southern/Purple)")
    
elif K == 3:
    # K=3: col0 = Southern (Purple), col1 = Northern (Green), col2 = New (Orange)
    # Reorder to: Northern (Green), Southern (Purple), Orange
    col_order = [1, 0, 2]
    print(f"K=3 column order: {col_order} (Northern/Green, Southern/Purple, Orange)")
    
else:
    # For K>3, use geographic-based ordering
    ma_samples = sample_info_sorted['group'] == 'Massachusetts'
    tx_samples = sample_info_sorted['group'] == 'Texas'
    ma_means = Q[ma_samples].mean(axis=0).values
    tx_means = Q[tx_samples].mean(axis=0).values
    
    # Column dominant in MA = northern (green)
    green_col = np.argmax(ma_means)
    # Column dominant in TX = southern (purple)
    purple_col = np.argmax(tx_means)
    
    remaining = [i for i in range(K) if i not in [green_col, purple_col]]
    col_order = [green_col, purple_col] + remaining
    print(f"K={K} column order: {col_order}")

print(f"Final column order: {col_order}")

Q = Q.iloc[:, col_order]
Q.columns = range(K)

# --- 3. Plotting HORIZONTAL ---

# Consistent color palette
# Green for Northern (left), Purple for Southern (middle), Orange for third (right)
if K == 2:
    faststructure_palette = ['#2D5C3E', '#6B4C9A']  # Green, Purple
elif K == 3:
    faststructure_palette = ['#2D5C3E', '#6B4C9A', '#FF6B35']  # Green, Purple, Orange
else:
    faststructure_palette = ['#2D5C3E', '#6B4C9A', '#FF6B35', '#00B5D9', '#F0B614', '#656510', '#A1B42A', '#0D5E63', '#002D57']

if K <= len(faststructure_palette):
    custom_colors = faststructure_palette[:K]
else:
    custom_colors = plt.cm.tab10.colors[:K]
    print(f"Warning: K={K} exceeds palette size. Using default colors.")

fig, ax = plt.subplots(figsize=(10, 45))
left = np.zeros(len(Q))

# Use barh (horizontal bars)
for i in range(K):
    ax.barh(range(len(Q)), Q.iloc[:, i], left=left, color=custom_colors[i], height=1.0)
    left += Q.iloc[:, i]

# Add group separation lines and labels
group_annotations = []
group_start_index = 0
current_group = groups_sorted[0]

for i in range(1, len(groups_sorted)):
    if groups_sorted[i] != current_group:
        ax.axhline(y=i - 0.5, color='black', linestyle='-', linewidth=2.5, zorder=2)
        group_center = (group_start_index + i - 1) / 2
        display_label = STATE_ABBREV.get(current_group, current_group)
        group_annotations.append({'center': group_center, 'label': display_label})
        current_group = groups_sorted[i]
        group_start_index = i

group_center = (group_start_index + len(groups_sorted) - 1) / 2
display_label = STATE_ABBREV.get(current_group, current_group)
group_annotations.append({'center': group_center, 'label': display_label})

# Place state labels using figure coordinates (far left)
for a in group_annotations:
    y_pos = 1 - ((a['center'] + 0.5) / len(Q))
    fig.text(0.01, y_pos, a['label'],
             ha='left', va='center', fontsize=10, fontweight='bold',
             transform=fig.transFigure)

ax.set_yticks(range(len(labels)))
ax.set_yticklabels(labels, fontsize=6, ha='right')
ax.set_xlabel("Ancestry Proportion", fontsize=10)
ax.set_ylabel("Samples (Sorted by Geography)", fontsize=10)
ax.set_title(f"fastSTRUCTURE K={K} - Grouped by State", fontsize=12)
ax.set_ylim(-0.5, len(Q) - 0.5)
ax.set_xlim(0, 1.0)
ax.set_xticks([0, 0.25, 0.5, 0.75, 1.0])
ax.invert_yaxis()

plt.subplots_adjust(left=0.15, right=0.98, top=0.98, bottom=0.02)
plt.savefig(output_pdf, bbox_inches="tight", dpi=300, format='jpg')
print(f"✅ Horizontal plot saved to {output_pdf}")
