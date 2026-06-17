import numpy as np
import glob
import re
import sys
import os

# --- PASTE THE CORRECTED parse_logs, parse_varQs, and utility functions here ---

# Since I don't have your specific corrected file, I will use the robust logic we established.
# You MUST ensure the contents of these functions match the final fixed code.

def parse_logs(file):
    """
    Reads a single log file and returns the final converged Marginal Likelihood.
    Returns None if not found.
    """
    final_likelihood_tag = 'Marginal Likelihood = '
    final_mle = None
    
    try:
        with open(file, 'r') as handle:
            for line in handle:
                if line.strip().startswith(final_likelihood_tag):
                    final_mle = float(line.strip().split('=')[1].strip())
                    
    except IOError:
        sys.stderr.write("Error: Could not open file: %s.\n" % file)
    except Exception:
        sys.stderr.write("Error parsing likelihood in file: %s.\n" % file)
            
    return final_mle

def parse_varQs(file):
    """
    Reads a single meanQ file and returns the estimated bestK (K_phi_star).
    Returns None if parsing fails.
    """
    try:
        with open(file, 'r') as handle:
            Q = np.array([[float(val) for val in line.strip().split()] for line in handle if line.strip()])
            
        if Q.size == 0:
            return None
            
        # Normalize rows to sum to 1
        Q_sum = Q.sum(axis=1, keepdims=True)
        Q_sum[Q_sum == 0] = 1.0 
        Q = Q / Q_sum
        
        N = Q.shape[0]
        C = np.cumsum(np.sort(Q.sum(0))[::-1])
        
        # Calculate best K (K_phi_star)
        return np.sum(C < N - 1) + 1
        
    except IOError:
        sys.stderr.write("Error: Could not open file: %s.\n" % file)
    except Exception as e:
        sys.stderr.write("Error processing .meanQ file %s: %s.\n" % (file, e))
        return None

# --- Main Compilation Logic ---

def compile_metrics(filetag="faststructure_K"):
    
    results = [] # To store [K, LLBO, K_phi_star] for each K
    
    # K values span from 1 to 10 based on your file listing
    for K in range(1, 11):
        # We need to find the specific log/meanQ file for this K, 
        # e.g., 'faststructure_K5.5.log'. The regex ensures we get the right file.
        
        # Find the log file (e.g., faststructure_K5.X.log)
        log_pattern = '%s%d.*.log' % (filetag, K)
        log_files = glob.glob(log_pattern)
        
        # Find the meanQ file (e.g., faststructure_K5.X.meanQ)
        meanQ_pattern = '%s%d.*.meanQ' % (filetag, K)
        meanQ_files = glob.glob(meanQ_pattern)
        
        if not log_files or not meanQ_files:
            sys.stderr.write(f"Warning: Files for K={K} not found. Skipping.\n")
            continue

        # For simplicity, we assume there is only one run per K (e.g., K5.5)
        # and take the first match found.
        llbo = parse_logs(log_files[0])
        k_phi_star = parse_varQs(meanQ_files[0])

        if llbo is not None and k_phi_star is not None:
            results.append([K, llbo, k_phi_star])
            
    return np.array(results)

if __name__ == "__main__":
    # The filetag is 'faststructure_K' based on your analysis
    metrics_array = compile_metrics(filetag="faststructure_K")
    
    # Save the compiled metrics to a file for easy plotting
    np.savetxt('k_metrics_data.txt', metrics_array, fmt='%d,%.6f,%d', 
               header='K,LLBO_Value,K_Phi_Star', delimiter=',')
    
    print("Metrics compiled and saved to k_metrics_data.txt")
