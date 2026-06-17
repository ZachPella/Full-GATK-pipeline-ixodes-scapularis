import numpy as np
import matplotlib.pyplot as plt

# Load the compiled data
try:
    # Skip the header line (row 0) and use the comma delimiter
    data = np.loadtxt('k_metrics_data.txt', delimiter=',', skiprows=1)
    
    K_values = data[:, 0]
    LLBO_values = data[:, 1]
    K_Phi_Star_values = data[:, 2]

except FileNotFoundError:
    print("Error: k_metrics_data.txt not found. Run extract_k_metrics.py first.")
    sys.exit(1)
except IndexError:
    print("Error: Data file is empty or formatted incorrectly.")
    sys.exit(1)


# --- PLOT 1: Approx. Log Marginal Likelihood (LLBO) vs. K ---

plt.figure(figsize=(7, 5))
plt.plot(K_values, LLBO_values, marker='o', linestyle='-', color='blue')

# Find the K that maximizes LLBO (for annotation)
max_llbo_k = K_values[np.argmax(LLBO_values)]

plt.title('Approx. Log Marginal Likelihood (LLBO) vs. Model Complexity (K)')
plt.xlabel('Model Complexity (K)')
plt.ylabel('LLBO (Approx. Log Marginal Likelihood)')
plt.grid(True, linestyle='--', alpha=0.6)
plt.axvline(x=max_llbo_k, color='red', linestyle='--', label=f'Max LLBO at K={int(max_llbo_k)}')
plt.legend()
plt.xticks(K_values) # Ensure integer ticks on X-axis
plt.tight_layout()
plt.savefig('LLBO_vs_K.png')
# plt.show() # Uncomment to display interactively


# --- PLOT 2: Estimated Model Components (K_phi_star) vs. K ---

plt.figure(figsize=(7, 5))
plt.plot(K_values, K_Phi_Star_values, marker='s', linestyle='-', color='green')

# Add the K=K line for reference
plt.plot(K_values, K_values, linestyle='--', color='gray', label='K = K Line')

plt.title('Estimated Optimal K ($K_{\phi^{*}}$) vs. Assumed Model Complexity (K)')
plt.xlabel('Assumed Model Complexity (K)')
plt.ylabel('Estimated Optimal Components ($K_{\phi^{*}}$)')
plt.grid(True, linestyle='--', alpha=0.6)
plt.xticks(K_values)
plt.yticks(K_values) # Ensure integer ticks on Y-axis
plt.legend()
plt.tight_layout()
plt.savefig('K_phi_star_vs_K.png')
# plt.show() # Uncomment to display interactively

print("Two line charts saved as LLBO_vs_K.png and K_phi_star_vs_K.png")
