import subprocess
import os
import pandas as pd

def run_command(command, check=True):
    """Executes a shell command and returns the output."""
    try:
        result = subprocess.run(command, text=True, check=check, capture_output=True)
        return result.stdout
    except subprocess.CalledProcessError as e:
        print(f"Error executing command: {e}")
        print(f"Error output: {e.stderr}")
        return None

def check_git_installed():
    """Checks if git is installed."""
    try:
        result = subprocess.run(['git', '--version'], capture_output=True, text=True, check=True)
        print(f"Git version: {result.stdout}")
    except subprocess.CalledProcessError:
        print("Git is not installed or not in the PATH!")
        exit()

def resolve_merge_conflicts():
    """Handles the merge conflicts and asks the user to resolve them."""
    print("\n### Merge Conflict Detected ###")
    conflict_files = run_command(["git", "status"])
    print(f"Conflict files:\n{conflict_files}")
    
    print("\n### Conflict Resolution Instructions ###")
    print("1. Open the conflicted files listed above.")
    print("2. Look for markers like <<<<<<<, =======, and >>>>>>> indicating the conflict areas.")
    print("3. Edit the files to resolve the conflicts and save your changes.")
    print("4. After resolving, stage the resolved files with 'git add <file>'.")
    print("5. Finally, commit the changes with 'git commit -m 'Resolved merge conflicts'.\n")
    
    developer_input = input("Have you resolved the conflicts? (Y/N): ").strip().lower()
    
    if developer_input == 'y':
        run_command(["git", "commit", "-m", "Resolved merge conflicts"])
        print("Conflicts resolved and changes committed.")
    else:
        print("Merge aborted. Please resolve the conflicts and rerun the script.")
        exit()

def commit_and_push(feature_branch):
    """Commit and push local changes."""
    print("Staging modified files...")
    run_command(["git", "add", "."])  # Staging all files (can be modified as needed)

    print("Committing changes...")
    commit_output = run_command(["git", "commit", "-m", "This is first automation commit..."])
    if commit_output:
        print(commit_output)

    # Ensure that the feature branch exists and is checked out
    check_branch_output = run_command(["git", "branch", "--list", feature_branch])
    if feature_branch not in check_branch_output:
        print(f"Branch {feature_branch} doesn't exist. Creating it...")
        run_command(["git", "checkout", "-b", feature_branch])

    # Push the feature branch
    print(f"Pushing changes to the {feature_branch} branch...")
    push_output = run_command(["git", "push", "origin", feature_branch])
    if push_output:
        print(push_output)

def create_pull_request(feature_branch, release_branch):
    """Create a pull request using GitHub CLI."""
    command = [
        "gh", "pr", "create", 
        "--base", release_branch, 
        "--head", feature_branch, 
        "--title", f"Merge {feature_branch} into {release_branch}",
        "--body", f"Automated PR to merge feature branch {feature_branch} into release branch {release_branch}."
    ]
    
    try:
        result = subprocess.run(command, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        print(f"Pull request created successfully from {feature_branch} to {release_branch}.")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while creating the pull request: {e}")
        print(f"Standard Output: {e.stdout}")
        print(f"Standard Error: {e.stderr}")

def perform_git_operations(excel_file):
    """Main function to perform git operations like pull, commit, push, and PR creation."""
    project_directory = os.path.dirname(os.path.realpath(__file__))
    
    check_git_installed()

    # Read Excel file to get repo_url, release_branch, and commit_message
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

    # Correct feature branch name based on release branch
    feature_branch = f"Feature_Datahub_{release_branch}"

    print(f"Feature branch name: {feature_branch}")

    os.chdir(project_directory)

    # Initialize git repository if not already initialized
    if not os.path.isdir(os.path.join(project_directory, ".git")):
        print("Initializing git repository...")
        run_command(["git", "init"])

    # Ensure remote exists
    remotes = run_command(["git", "remote", "get-url", "origin"])
    if remotes is None:
        print("Setting up remote repository...")
        run_command(["git", "remote", "add", "origin", repo_url])

    # Pull latest changes
    print("Pulling latest changes from remote...")
    pull_output = run_command(["git", "pull", "origin", release_branch, "--allow-unrelated-histories"], check=False)

    # If there are merge conflicts, handle them
    if pull_output and "CONFLICT" in pull_output:
        resolve_merge_conflicts()
    
    # Commit and push changes
    commit_and_push(feature_branch)

    # Create the pull request
    create_pull_request(feature_branch, release_branch)

    # After PR creation, check if there are merge conflicts in the pull request
    print("\n### Checking for Merge Conflicts in Pull Request ###")
    conflict_check = run_command(["gh", "pr", "view", "--json", "mergeable", "--jq", ".mergeable"])
    
    if conflict_check and conflict_check.strip().lower() == 'false':
        print("\nMerge conflict detected in PR.")
        resolve_merge_conflicts()
    else:
        print("\nNo conflicts detected in the pull request.")
        print("Proceeding with the merge.")

    # Finally, merge the PR if there are no conflicts
    print("\nMerging pull request...")
    run_command(["gh", "pr", "merge", "--auto"])

    print("\nMerge completed successfully.")

