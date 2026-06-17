#!/usr/bin/env python3
import matplotlib.pyplot as plt
import pandas as pd
import numpy as np
import sys

# --- Configuration ---
K = 2
q_file = "combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi.LD_pruned_admixture.2.Q"
fam_file = "combined_ixodes_all_variants_snps_passing_only.maf01.miss05.mac2.bi.LD_pruned_admixture.fam"
label_file = "name_and_state_cleaned.txt"
output_file = "admixture_K2_by_state_horizontal.jpg"

# --- 1. Read Q-matrix ---
print(f"Reading Q-matrix from: {q_file}")
Q = pd.read_csv(q_file, sep=r'\s+', header=None)
print(f"Read {len(Q)} samples with {Q.shape[1]} ancestry components")

# --- 2. Read FAM file for sample order ---
fam = pd.read_csv(fam_file, sep=r'\s+', header=None, usecols=[0, 1])
fam_samples = fam[1].tolist()
print(f"Read {len(fam_samples)} samples from FAM file")

# --- 3. Read metadata and create lookup ---
meta_labels = [line.strip() for line in open(label_file)]
print(f"Read {len(meta_labels)} labels from metadata")

meta_lookup = {}
for label in meta_labels:
    parts = label.rsplit('_', 1)
    if len(parts) == 2:
        short_name = parts[0]
        meta_lookup[short_name] = label
    for state in ['South_Dakota', 'North_Carolina', 'South_Carolina', 'Rhode_Island']:
        if label.endswith(state):
            short_name = label.replace('_' + state, '')
            meta_lookup[short_name] = label
            break

labels = []
for sample in fam_samples:
    lookup_name = sample.replace('evi', '') if sample.startswith('evi') else sample
    if sample in meta_lookup:
        labels.append(meta_lookup[sample])
    elif lookup_name in meta_lookup:
        labels.append(meta_lookup[lookup_name])
    else:
        matched = False
        for key in meta_lookup:
            if key.startswith(sample) or sample.startswith(key):
                labels.append(meta_lookup[key])
                matched = True
                break
        if not matched:
            labels.append(sample + "_Unknown")
            print(f"Warning: No match for {sample}")

print(f"Matched {len(labels)} labels")

# --- 4. Geographic ordering ---
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
    'Win': 0, 'FL': 1, 'TR': 2, 'Schram': 3, 'CH': 4,
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

def get_nebraska_sort_key(label):
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
sample_info['secondary_sort'] = sample_info['label'].apply(get_nebraska_sort_key)

sample_info_sorted = sample_info.sort_values(
    by=['primary_sort', 'secondary_sort', 'label']
).reset_index(drop=True)

new_indices = sample_info_sorted['original_index'].tolist()
Q = Q.iloc[new_indices, :]
labels = sample_info_sorted['label'].tolist()
groups_sorted = sample_info_sorted['group'].tolist()
print(f"Sorted {len(Q)} samples by geography")

# Swap columns
Q = Q[[1, 0]]
Q.columns = [0, 1]

# --- 5. Plot HORIZONTAL ---
unmc_palette = ['#AD122A', '#129DBF']

fig, ax = plt.subplots(figsize=(10, 45))
left = np.zeros(len(Q))

# Use barh (horizontal bars)
for i in range(K):
    ax.barh(range(len(Q)), Q.iloc[:, i], left=left, color=unmc_palette[i], height=1.0)
    left += Q.iloc[:, i]

# Add group separation lines and collect group info
group_annotations = []
group_start_index = 0
current_group = groups_sorted[0]

for i in range(1, len(groups_sorted)):
    if groups_sorted[i] != current_group:
        ax.axhline(y=i - 0.5, color='black', linestyle='-', linewidth=2.5, zorder=2)
        group_center = (group_start_index + i - 1) / 2
        display_label = STATE_ABBREV.get(current_group, current_group)  # Use abbreviation
        group_annotations.append({'center': group_center, 'label': display_label})
        current_group = groups_sorted[i]
        group_start_index = i

group_center = (group_start_index + len(groups_sorted) - 1) / 2
display_label = STATE_ABBREV.get(current_group, current_group)  # Use abbreviation
group_annotations.append({'center': group_center, 'label': display_label})

# Place state labels using figure coordinates (far left, outside plot area)
for a in group_annotations:
    # Calculate y position in figure coordinates (0 to 1)
    y_pos = 1 - ((a['center'] + 0.5) / len(Q))
    fig.text(0.01, y_pos, a['label'], 
             ha='left', va='center', fontsize=10, fontweight='bold',
             transform=fig.transFigure)

ax.set_yticks(range(len(labels)))
ax.set_yticklabels(labels, fontsize=6, ha='right')
ax.set_xlabel("Ancestry Proportion", fontsize=10)
ax.set_ylabel("Samples (Sorted by Geography)", fontsize=10)
ax.set_title(f"ADMIXTURE K={K} - Grouped by State", fontsize=12)
ax.set_ylim(-0.5, len(Q) - 0.5)
ax.set_xlim(0, 1.0)
ax.set_xticks([0, 0.25, 0.5, 0.75, 1.0])
ax.invert_yaxis()

plt.subplots_adjust(left=0.15, right=0.98, top=0.98, bottom=0.02)
plt.savefig(output_file, bbox_inches="tight", dpi=300, format='jpg')
print(f"✅ Plot saved to {output_file}")
