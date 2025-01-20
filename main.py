import os
import re
import pandas as pd
from datetime import datetime
import shutil
from GIT import Git_Steps_1to6, Git_Steps_7to13
class SQLEntityModifier:
    def __init__(self, file_path, log_file):
        self.file_path = file_path
        self.file_content = self.read_file()
        self.log_file = log_file

    def read_file(self):
        """Read the SQL file, handling different encodings."""
        try:
            with open(self.file_path, 'r', encoding='utf-8') as file:
                return file.read()
        except UnicodeDecodeError:
            try:
                with open(self.file_path, 'r', encoding='utf-16') as file:
                    return file.read()
            except Exception as e:
                self.log(f"Error reading file {self.file_path}: {str(e)}")
                raise

    def write_file(self, new_file_path):
        """Save the modified file content back to the file."""
        try:
            with open(new_file_path, 'w', encoding='utf-8') as file:
                file.write(self.file_content)
        except Exception as e:
            self.log(f"Error writing file {new_file_path}: {str(e)}")
            raise

    def log(self, message):
        """Append a log message to the log file with date and time."""
        with open(self.log_file, 'a', encoding='utf-8') as log:
            log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {message}\n")

    def apply_head_pattern_and_tail(self, object_name, object_type, folder_name=None):
        """Apply the Head for all object types, including a specific case for 'File' (Rollback and ddldml)."""
        try:
            head = f'/*DBTYPE:SQLSERVER|TARGETDB:HPFSIDS*/\n\n'

            # Special handling for 'File' type (Rollback case)
            if object_type.lower() == 'file' and folder_name.lower() == 'rollback':
                folder_path = os.path.join(os.path.dirname(self.file_path), 'Rollback')
                os.makedirs(folder_path, exist_ok=True)

                file_name = os.path.basename(self.file_path)

                # Only process if the file name matches the object name (case-insensitive)
                if file_name.lower() == f"{object_name.lower()}.sql":
                    # Check if the file content already starts with the Head
                    if not self.file_content.strip().startswith(head.strip()):
                        self.file_content = head + self.file_content
                        self.log(f"Added Head to Rollback file: {object_name}")
                    else:
                        self.log(f"Head already exists in Rollback file: {object_name}, not adding.")

                    new_file_path = os.path.join(folder_path, file_name)
                    self.write_file(new_file_path)

                    log_message = (
                        f"DB Object Type: Rollback\n"
                        f"DB Object Name: {object_name}\n"
                        f"Processed and saved Rollback file at: {new_file_path}\n"
                        "------------------------------------"
                    )
                    self.log(log_message)
                return  # Exit after processing Rollback case

            # Additional handling for 'ddldml' folder case
            elif object_type.lower() == 'file' and folder_name.lower() == 'ddldml':
                file_name = os.path.basename(self.file_path)
                file_name_lower = file_name.lower()

                dml_folder = os.path.join(os.path.dirname(self.file_path), 'ddldml')
                os.makedirs(dml_folder, exist_ok=True)

                if file_name_lower == 'master_ids_dml.sql':
                    new_file_path = os.path.join(dml_folder, 'MASTER_IDS_DML.sql')
                    if not self.file_content.strip().startswith(head.strip()):
                        self.file_content = head + self.file_content
                        self.log(f"Added Head to DML file: {file_name}")
                    else:
                        self.log(f"Head already exists in DML file: {file_name}, not adding.")

                    self.write_file(new_file_path)

                    log_message = (
                        f"DB Object Type: File (DML)\n"
                        f"DB Object Name: MASTER_IDS_DML.sql\n"
                        f"File copied to ddldml folder: {new_file_path}\n"
                        "------------------------------------"
                    )
                    self.log(log_message)
                return  # Exit after processing DML case

            # Handle other types: Procedure, View, Function, Synonym, TableType
            specific_schema, specific_name = '', object_name
            if '.' in object_name:
                specific_schema, specific_name = object_name.split('.')

            # Different handling per object type
            if object_type.lower() == 'procedure':
                pattern = (
                    f"IF EXISTS (SELECT * FROM SYS.OBJECTS WHERE OBJECT_ID = OBJECT_ID(N'{object_name}') AND TYPE IN (N'P', N'PC'))\n"
                    f"BEGIN\n    DROP PROCEDURE {object_name}\nEND\nGO\n"
                )
                tail = f'GO\nGRANT EXECUTE ON {object_name} TO DMUsr01;\nGO\n'

            elif object_type.lower() == 'view':
                pattern = (
                    f"IF EXISTS (SELECT * FROM SYS.VIEWS WHERE OBJECT_ID = OBJECT_ID(N'{object_name}'))\n"
                    f"BEGIN\n    DROP VIEW {object_name}\nEND\nGO\n"
                )
                tail = f'GO\nGRANT SELECT ON {object_name} TO DMUsr01;\nGO\n'

            elif object_type.lower() == 'function':
                drop_logic = (
                    f"IF EXISTS (SELECT * FROM INFORMATION_SCHEMA.ROUTINES WHERE SPECIFIC_SCHEMA = '{specific_schema}' "
                    f"AND SPECIFIC_NAME = '{specific_name}' AND ROUTINE_TYPE = 'FUNCTION')\n"
                    f"BEGIN\n    DROP FUNCTION {object_name}\nEND\nGO\n"
                )
                pattern = drop_logic
                tail = f'GO\nGRANT EXECUTE ON {object_name} TO DMUsr01;\nGO\n'

            elif object_type.lower() == 'synonym':
                pattern = (
                    f"IF EXISTS (SELECT * FROM SYS.SYNONYMS WHERE NAME = N'{object_name}')\n"
                    f"BEGIN\n    DROP SYNONYM {object_name}\nEND\nGO\n"
                )
                tail = f'GO\nGRANT EXECUTE ON {object_name} TO DMUsr01;\nGO\n'

            elif object_type.lower() == 'tabletype':
                schema_name = specific_schema or ''
                table_type_name = specific_name or object_name
                pattern = (
                    f"IF NOT EXISTS (SELECT * FROM sys.types st JOIN sys.schemas ss ON st.schema_id = ss.schema_id "
                    f"WHERE st.name = N'{table_type_name}' AND ss.name = N'{schema_name}')\nBEGIN\n"
                )
                tail = f"GO\nGRANT EXECUTE ON type::{object_name} TO DMUsr01;\nGO\n"

            # Update content with head, pattern, and tail
            self.file_content = head + pattern + self.file_content + "\n\n" + tail

            # Log the detailed message
            log_message = (
                f"DB Object Type: {object_type}\n"
                f"DB Object Name: {object_name}\n"
                f"Added Head: {head.strip()}\n"
                f"Added Pattern: {pattern.strip()}\n"
                f"Added Tail: {tail.strip()}\n"
                "------------------------------------"
            )
            self.log(log_message)

        except Exception as e:
            self.log(f"Error applying head/pattern/tail for {object_name} ({object_type}): {str(e)}")
            raise


    def process_create_statements(self):
        """Process CREATE statements and apply Head/Pattern/Tail based on the type."""
        create_patterns = {
            'procedure': re.compile(r"CREATE\s+PROCEDURE\s+(\[?[a-zA-Z0-9_]+\]?\.\[?[a-zA-Z0-9_]+\]?|\[?[a-zA-Z0-9_]+\]?)", re.IGNORECASE),
            'view': re.compile(r"CREATE\s+VIEW\s+(\[?[a-zA-Z0-9_]+\]?(?:\.\[?[a-zA-Z0-9_]+\]?)?)", re.IGNORECASE),
            'function': re.compile(r"CREATE\s+FUNCTION\s+(\[?[a-zA-Z0-9_]+\]?\.\[?[a-zA-Z0-9_]+\]?|\[?[a-zA-Z0-9_]+\]?)\s*\(", re.IGNORECASE),
            'synonym': re.compile(r"CREATE\s+SYNONYM\s+(\[?[a-zA-Z0-9_]+\]?\.\[?[a-zA-Z0-9_]+\]?|\[?[a-zA-Z0-9_]+\]?)\s+FOR", re.IGNORECASE),
            'tabletype': re.compile(r"CREATE\s+TYPE\s+(\[?[a-zA-Z0-9_]+\]?\.\[?[a-zA-Z0-9_]+\]?|\[?[a-zA-Z0-9_]+\]?)\s+AS\s+TABLE", re.IGNORECASE),
        }

        for obj_type, pattern in create_patterns.items():
            try:
                matches = pattern.findall(self.file_content)
                for match in matches:
                    if obj_type == 'tabletype' and re.match(r'(?i)^\[?dbo\]?\.\[?TestType\]?$|^TestType$', match):
                        continue
                    self.apply_head_pattern_and_tail(match, obj_type)
            except Exception as e:
                self.log(f"Error processing {obj_type} statements: {str(e)}")
                raise

    def process_and_save(self, new_file_path):
        """Process the SQL file and save the modified content."""
        try:
            self.process_create_statements()
            self.write_file(new_file_path)
        except Exception as e:
            self.log(f"Error processing and saving file {self.file_path}: {str(e)}")
            raise

def create_log_folder(base_directory):
    """Create a log folder if it doesn't exist and return the log file path."""
    try:
        log_folder = os.path.join(base_directory, 'log')
        os.makedirs(log_folder, exist_ok=True)
        log_file_name = f"log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt"
        return os.path.join(log_folder, log_file_name)
    except Exception as e:
        raise Exception(f"Error creating log folder: {str(e)}")

import os
import re
import pandas as pd
import shutil
import sqlparse
from datetime import datetime

def table_ddl(base_directory, csv_path, log_file):
    """Process 'Table' DB Object Type and append to MASTER_IDS_DDL.sql."""
    try:
        # Define the path for the ddldml folder and create it if it doesn't exist
        ddldml_folder = os.path.join(base_directory, 'ddldml')
        os.makedirs(ddldml_folder, exist_ok=True)

        # Define the master file path inside ddldml folder
        master_file_path_ddldml = os.path.join(ddldml_folder, 'MASTER_IDS_DDL.sql')

        # The head to be added to the master file (only once)
        head = f'/*DBTYPE:SQLSERVER|TARGETDB:HPFSIDS*/\n\n'

        # Load the parameter file (make sure it contains 'DB Object Type' and 'DB Object Name')
        df = pd.read_excel(csv_path)

        # Filter for table objects only
        table_files = df[df['DB Object Type'].str.lower() == 'table']['DB Object Name'].tolist()

        # Check if the master file exists
        if os.path.exists(master_file_path_ddldml):
            # Read the current content of the master file
            with open(master_file_path_ddldml, 'r') as master_file:
                current_content = master_file.read()

            # Remove any existing head from the content
            current_content = re.sub(r"^\s*/\*DBTYPE:SQLSERVER\|TARGETDB:HPFSIDS\*/\s*\n", "", current_content)

            # Now write the head and the content (with the head removed)
            with open(master_file_path_ddldml, 'w') as master_file:
                master_file.write(head + current_content)
                log_message = f"Re-written {master_file_path_ddldml} with the head."
                with open(log_file, 'a') as log:
                    log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {log_message}\n")
        else:
            # If the master file doesn't exist, create a new file with the head
            with open(master_file_path_ddldml, 'w') as master_file:
                master_file.write(head)
                log_message = f"Created {master_file_path_ddldml} with the head."
                with open(log_file, 'a') as log:
                    log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {log_message}\n")

        # Now append content (tables) to the master file
        with open(master_file_path_ddldml, 'a') as master_file:
            for table_name in table_files:
                # Define the pattern and tail for the table
                pattern = (
                    f"PRINT 'Start Executing : MASTER_IDS_DDL.SQL'\n"
                    f"-----------------Start File-----MASTER_IDS_DDL.SQL-----------------\n\n"
                    f"IF EXISTS (SELECT * FROM SYS.OBJECTS WHERE OBJECT_ID = OBJECT_ID(N'{table_name}') AND TYPE IN (N'U'))\n"
                    f"BEGIN\n"
                    f"    --DROP TABLE {table_name}\n"
                    f"    PRINT '>> CUSTOMER PORTAL : TABLE {table_name} EXISTS >>'\n"
                    f"END\n\n"
                    f"IF NOT EXISTS (SELECT * FROM SYS.OBJECTS WHERE OBJECT_ID = OBJECT_ID(N'{table_name}') AND TYPE IN (N'U'))\n"
                    f"BEGIN\n"
                    f"    PRINT '>> CUSTOMER PORTAL : TABLE {table_name} CREATED >>'\n"
                    f"END\n\n"
                )

                tail = (
                    f"PRINT '>> CUSTOMER PORTAL : TABLE {table_name} CREATED >>'\n"
                    "END\n\n"
                )

                # Now read the content of the table file (assuming table file is in the base directory with .sql extension)
                table_file_path = os.path.join(base_directory, f"{table_name}.sql")
                if os.path.exists(table_file_path):
                    with open(table_file_path, 'r') as table_file:
                        table_content = table_file.read()
                    
                    # Remove any existing head from the content (if present anywhere in the file)
                    table_content = table_content.lstrip()  # Remove leading whitespaces from the entire file content
                    table_content = re.sub(r"^\s*/\*DBTYPE:SQLSERVER\|TARGETDB:HPFSIDS\*/\s*\n", "", table_content)

                    prettified = sqlparse.format(table_content, reindent=True, keyword_case='upper')

                    # Remove leading spaces from every line (for consistency)
                    prettified = "\n".join(line.lstrip() for line in prettified.splitlines())

                    # Append the pattern, prettified table content, and tail to the master file
                    master_file.write(pattern)
                    master_file.write(prettified)  # Insert the beautified table content
                    master_file.write(tail)
                    # Log the success of appending each table
                    log_message = f"Appended and beautified pattern and content for {table_name} to {master_file_path_ddldml}."
                    with open(log_file, 'a') as log:
                        log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {log_message}\n")
                else:
                    # Log the warning for missing table files
                    warning_message = f"Warning: Table file {table_file_path} not found."
                    with open(log_file, 'a') as log:
                        log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {warning_message}\n")

        # Log the overall success
        log_message = f"Successfully processed and appended {len(table_files)} table(s) to {master_file_path_ddldml}."
        with open(log_file, 'a') as log:
            log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {log_message}\n")
        
        # Cleanup: Remove any other unnecessary files in the ddldml folder
        for file_name in os.listdir(ddldml_folder):
            if file_name not in ['MASTER_IDS_DDL.sql', 'MASTER_IDS_DML.sql']:
                file_path = os.path.join(ddldml_folder, file_name)
                if os.path.isfile(file_path):
                    os.remove(file_path)

    except Exception as e:
        # Handle and log errors
        error_message = f"Error processing table files: {str(e)}"
        with open(log_file, 'a') as log:
            log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {error_message}\n")
        raise  # Optionally re-raise the exception for further handling

def datafix(base_directory, log_file):
    """Find files with 'Datafix' in their name and copy them to the 'One Time Run - ONLY' folder."""
    try:
        # Create the "One Time Run - ONLY" folder if it doesn't exist
        one_time_run_folder = os.path.join(base_directory, 'One Time Run - ONLY')
        os.makedirs(one_time_run_folder, exist_ok=True)

        # Loop through all files in the base directory
        for file_name in os.listdir(base_directory):
            if 'datafix' in file_name.lower() and file_name.endswith('.sql'):
                source_path = os.path.join(base_directory, file_name)
                destination_path = os.path.join(one_time_run_folder, file_name)

                # Copy the file
                shutil.copy(source_path, destination_path)

                # Log the action
                log_message = f"Copied {file_name} to {one_time_run_folder}."
                with open(log_file, 'a') as log:
                    log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {log_message}\n")

    except Exception as e:
        error_message = f"Error processing datafix files: {str(e)}"
        with open(log_file, 'a') as log:
            log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {error_message}\n")
        raise

import os
import shutil
from datetime import datetime

def move_processed_files(base_directory):
    """
    Moves the processed folders (like 'Proc', 'ddldml', 'function', 'Rollback', etc.)
    and their associated .sql files from the base directory to a subfolder inside 'Processed_Files_GIT'.
    """
    try:
        # Define the 'Processed_Files_GIT' directory
        processed_folder = os.path.join(base_directory, 'Processed_Files_GIT')
        
        # If the 'Processed_Files_GIT' folder doesn't exist, create it
        if not os.path.exists(processed_folder):
            os.makedirs(processed_folder)
        
        # Create a subfolder with the current date and time (for tracking)
        current_datetime = datetime.now().strftime('%Y%m%d_%H%M%S')
        subfolder_name = f"Processed_{current_datetime}"
        subfolder_path = os.path.join(processed_folder, subfolder_name)
        
        # Create the subfolder
        os.makedirs(subfolder_path)
        
        # List of folders to check for processed .sql files
        folders_to_check = ['Procs', 'ddldml', 'Function', 'Rollback','One Time Run - ONLY','Synonyms','Tabletypes','Views']
        
        # Move processed folders and .sql files
        for folder in folders_to_check:
            folder_path = os.path.join(base_directory, folder)

            # If the folder exists
            if os.path.isdir(folder_path):
                # Check if there are any .sql files inside the folder
                for file in os.listdir(folder_path):
                    if file.endswith('.sql'):
                        sql_file_path = os.path.join(folder_path, file)
                        
                        # Move the .sql file to the subfolder
                        shutil.move(sql_file_path, os.path.join(subfolder_path, file))
                
                # Move the folder itself to the subfolder
                shutil.move(folder_path, os.path.join(subfolder_path, folder))
        
        # Check for .sql files directly in the base directory and move them
        for file in os.listdir(base_directory):
            if file.endswith('.sql'):
                sql_file_path = os.path.join(base_directory, file)
                shutil.move(sql_file_path, os.path.join(subfolder_path, file))
        
        # Print a message indicating the files and folders have been moved
        print(f"Processed files and folders are moved to {subfolder_path}")

    except Exception as e:
        print(f"Error in moving files: {str(e)}")


def process_files_with_csv(file_paths, csv_path, log_file):
    """Process files based on CSV input."""
    try:
        df = pd.read_excel(csv_path)

        # Clean object names from the CSV
        df['DB Object Name Cleaned'] = df['DB Object Name'].str.replace(r'[\[\]]', '', regex=True).str.lower()
        object_dict = df.set_index('DB Object Name Cleaned')['DB Object Type'].to_dict()

        processed_objects = set()

        for file_path in file_paths:
            file_name = os.path.basename(file_path).replace('.sql', '').lower()
            object_type = object_dict.get(file_name)

            if object_type:
                folder_name = df[df['DB Object Name Cleaned'] == file_name]['Folder'].values[0]
                folder_path = os.path.join(os.path.dirname(file_path), folder_name)
                os.makedirs(folder_path, exist_ok=True)

                new_file_path = os.path.join(folder_path, file_name + '.sql')

                modifier = SQLEntityModifier(file_path, log_file)

                # Handle Rollback and ddldml cases
                if object_type.lower() == 'file' and folder_name.lower() == 'rollback':
                    modifier.apply_head_pattern_and_tail(file_name, object_type, 'rollback')
                    processed_objects.add(file_name)
                elif object_type.lower() == 'file' and folder_name.lower() == 'ddldml':
                    modifier.apply_head_pattern_and_tail(file_name, object_type, 'ddldml')
                    processed_objects.add(file_name)
                else:
                    # Process the general types
                    modifier.process_and_save(new_file_path)
                    processed_objects.add(file_name)

        # Log missing objects
        missing_objects = set(object_dict.keys()) - processed_objects
        if missing_objects:
            for obj in missing_objects:
                log_message = f"No SQL file found for {obj}."
                print(log_message)  # Optional: print on console
                with open(log_file, 'a', encoding='utf-8') as log:
                    log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - {log_message}\n")

    except Exception as e:
        with open(log_file, 'a', encoding='utf-8') as log:
            log.write(f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Error processing files with CSV: {str(e)}\n")



def main():
    base_directory = os.path.dirname(os.path.abspath(__file__))
    csv_path = os.path.join(base_directory, 'Parameter.xlsx')
    log_file = create_log_folder(base_directory)

    
    # Continue with other SQL file processing
    sql_file_paths = [os.path.join(base_directory, f) for f in os.listdir(base_directory) if f.endswith('.sql')]
    process_files_with_csv(sql_file_paths, csv_path, log_file)
    
    
    df = pd.read_excel(csv_path)

    # Check for 'table' object types
    object_type_table = df['DB Object Type'].str.lower() == 'table'

    # Check if any entry in the 'Folder' column is 'ddldml' (case-insensitive)
    folder_name_ddldml = df['Folder'].str.lower() == 'ddldml'

    # Check if MASTER_IDS_DDL.sql exists in the base directory (case-insensitive)
    master_ddl_exists = any(f.lower() == 'master_ids_ddl.sql' for f in os.listdir(base_directory))

    # Condition: if there are 'table' objects and 'ddldml' folder, or MASTER_IDS_DDL.sql exists
    if (object_type_table.any() and folder_name_ddldml.any()) or master_ddl_exists:
        table_ddl(base_directory, csv_path, log_file)
    
    # Call the datafix function to process Datafix files
    datafix(base_directory, log_file)

    base_directory = os.path.dirname(os.path.abspath(__file__))
    excel_path = os.path.join(base_directory, 'Parameter.xlsx')

    # Step 1 to 6 (Git initialization, branch creation, etc.)
    feature_branch, release_branch, commit_message = Git_Steps_1to6(excel_path)

    # Step 7 to 13 (Commit changes, push to remote, create pull request)
    Git_Steps_7to13(excel_path)

if __name__ == '__main__':
    main()
