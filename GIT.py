import os
import subprocess
import pandas as pd
import re

# Function to execute shell commands and capture the output
def run_command(command):
    try:
        result = subprocess.run(command, text=True, check=True, capture_output=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        print(f"Error output: {e.stderr}")
        return None

# Function to check if Git is installed
def check_git_installed():
    try:
        result = subprocess.run(['git', '--version'], capture_output=True, text=True, check=True)
        print(f"Git version: {result.stdout}")
    except subprocess.CalledProcessError:
        print("Git is not installed or not in the PATH!")
        exit()

# Function to commit any local changes before switching branches
def commit_local_changes():
    status_output = run_command(["git", "status", "--porcelain"])
    if status_output:
        print("Committing local changes before switching branches...")
        
        # Ensure no temporary files (like ~$ files) are added
        temp_files = [f for f in os.listdir() if f.startswith('~$')]
        for temp_file in temp_files:
            print(f"Skipping temporary file: {temp_file}")
            os.remove(temp_file)

        run_command(["git", "add", "."])  # Stage all files
        run_command(["git", "commit", "-m", "Committing local changes before switching branches"])

# Function to create and push the feature branch
def create_and_push_feature_branch(feature_branch, release_branch):
    # Check if the feature branch exists locally
    branch_check = run_command(["git", "branch", "--list", feature_branch])
    if feature_branch not in branch_check:
        print(f"Feature branch {feature_branch} does not exist locally. Creating it...")
        # Create feature branch from release branch
        run_command(["git", "checkout", "-b", feature_branch, "origin/" + release_branch])

    # Commit any changes if needed
    commit_local_changes()

    # Push to remote repository
    print(f"Pushing changes to the {feature_branch} branch...")
    push_output = run_command(["git", "push", "origin", feature_branch])
    if push_output:
        print(push_output)

# Function to create a pull request from the feature branch to the release branch
def create_pull_request(feature_branch, release_branch, commit_message):
    print(f"Creating a pull request from {feature_branch} to {release_branch}...")
    pr_output = run_command([
        "gh", "pr", "create", "--base", release_branch, "--head", feature_branch,
        "--title", commit_message, "--body", "Auto-generated PR"
    ])
    if pr_output:
        print(pr_output)

# Main function to execute Git steps 1 to 6
def Git_Steps_1to6(excel_file):
    print("Executing Git Steps 1 to 6...")

    # Step 1: Initialize git repository if not already initialized
    if not os.path.isdir(".git"):
        print("Initializing git repository...")
        run_command(["git", "init"])

    # Step 2: Read the Parameter.xlsx file to get the repo_url, release_branch, Commit_Message
    try:
        df = pd.read_excel(excel_file)
    except Exception as e:
        print(f"Error reading the Excel file: {e}")
        exit()

    repo_url = df['repo_url'].iloc[0] if pd.notna(df['repo_url'].iloc[0]) else None
    release_branch = df['release_branch'].iloc[0] if pd.notna(df['release_branch'].iloc[0]) else None
    commit_message = df['Commit_Message'].iloc[0] if pd.notna(df['Commit_Message'].iloc[0]) else "Default commit message"

    if not repo_url or not release_branch:
        print("Error: repo_url or release_branch are missing in the first row!")
        exit()

    # Step 3: Extract fiscal year and quarter from the release branch
    release_branch_pattern = r"LMS-rel(FY\d{2}Q\d)"
    match = re.search(release_branch_pattern, release_branch)

    if not match:
        print(f"Error: Release branch '{release_branch}' does not match the expected pattern.")
        exit()

    fiscal_year_quarter = match.group(1)

    # Step 4: Create the feature branch name based on the release branch
    feature_branch = f"Feature_Datahub_{fiscal_year_quarter}{'-OC' if 'OC' in release_branch else '-ER' if 'ER' in release_branch else ''}"
    print(f"Feature branch name: {feature_branch}")

    # Step 5: Initialize remote if not already configured
    remotes = run_command(["git", "remote", "get-url", "origin"])
    if remotes is None:
        print("Setting up remote repository...")
        run_command(["git", "remote", "add", "origin", repo_url])

    # Step 6: Check out the latest release branch
    print(f"Fetching latest remote branches...")
    run_command(["git", "fetch", "--all"])

    # Create and push the feature branch
    create_and_push_feature_branch(feature_branch, release_branch)

    return feature_branch, release_branch, commit_message

# Main function to handle Git Steps 7 to 13
def Git_Steps_7to13(excel_file):
    print("Executing Git Steps 7 to 13...")

    # Read the Parameter.xlsx file again for commit message and branch names
    try:
        df = pd.read_excel(excel_file)
    except Exception as e:
        print(f"Error reading the Excel file: {e}")
        exit()

    commit_message = df['Commit_Message'].iloc[0] if pd.notna(df['Commit_Message'].iloc[0]) else "Default commit message"
    release_branch = df['release_branch'].iloc[0] if 'release_branch' in df.columns and pd.notna(df['release_branch'].iloc[0]) else None

    if not release_branch:
        print("Error: Release branch is missing!")
        exit()

    # Generate the feature branch name from the release branch
    feature_branch = f"Feature_Datahub_{release_branch[8:]}"

    # Commit local changes, push, and create PR
    create_and_push_feature_branch(feature_branch, release_branch)
    create_pull_request(feature_branch, release_branch, commit_message)
