#!/usr/bin/env python3
"""
Script to add ALL missing Swift files to the Xcode project.
This will ensure every Swift file in the project directory is properly referenced.
"""

import os
import re
import uuid
import subprocess

def get_files_on_disk():
    """Get all Swift files on disk (excluding derived data)"""
    result = subprocess.run(
        ["find", ".", "-name", "*.swift", "-not", "-path", "./DerivedData/*"],
        capture_output=True, text=True, cwd="/Users/danielstevens/Desktop/PlannerApp"
    )
    files = [f.replace("./", "") for f in result.stdout.strip().split("\n") if f]
    return sorted(files)

def get_files_in_project():
    """Get all Swift files currently referenced in the project"""
    project_path = "/Users/danielstevens/Desktop/PlannerApp/PlannerApp.xcodeproj/project.pbxproj"
    
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Extract file paths from the project file
    file_pattern = r'path = ([^;]+\.swift);'
    matches = re.findall(file_pattern, content)
    files = [match.strip('"') for match in matches]
    return sorted(files)

def generate_uuid():
    """Generate a UUID in the format used by Xcode"""
    return uuid.uuid4().hex.upper()[:24]

def add_files_to_project(missing_files):
    """Add missing files to the Xcode project"""
    project_path = "/Users/danielstevens/Desktop/PlannerApp/PlannerApp.xcodeproj/project.pbxproj"
    
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Find the PBXBuildFile section
    build_file_section = re.search(r'(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)', content, re.DOTALL)
    
    # Find the PBXFileReference section
    file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)', content, re.DOTALL)
    
    # Find the Sources build phase
    sources_section = re.search(r'(files = \([^)]*?\);.*?name = Sources;)', content, re.DOTALL)
    
    if not all([build_file_section, file_ref_section, sources_section]):
        print("Error: Could not find required sections in project file")
        return
    
    new_build_files = []
    new_file_refs = []
    new_source_entries = []
    
    for file_path in missing_files:
        filename = os.path.basename(file_path)
        
        # Generate UUIDs
        file_ref_uuid = generate_uuid()
        build_file_uuid = generate_uuid()
        
        # Create entries
        build_file_entry = f"\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};"
        file_ref_entry = f"\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"{file_path}\"; sourceTree = \"<group>\"; }};"
        source_entry = f"\t\t\t\t{build_file_uuid} /* {filename} in Sources */,"
        
        new_build_files.append(build_file_entry)
        new_file_refs.append(file_ref_entry)
        new_source_entries.append(source_entry)
    
    # Insert new build files
    build_section_end = build_file_section.group(1).rfind("/* End PBXBuildFile section */")
    new_build_section = (build_file_section.group(1)[:build_section_end] + 
                        "\n".join(new_build_files) + "\n" +
                        build_file_section.group(1)[build_section_end:])
    content = content.replace(build_file_section.group(1), new_build_section)
    
    # Insert new file references
    file_ref_section = re.search(r'(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)', content, re.DOTALL)
    file_section_end = file_ref_section.group(1).rfind("/* End PBXFileReference section */")
    new_file_section = (file_ref_section.group(1)[:file_section_end] + 
                       "\n".join(new_file_refs) + "\n" +
                       file_ref_section.group(1)[file_section_end:])
    content = content.replace(file_ref_section.group(1), new_file_section)
    
    # Insert new source entries
    sources_section = re.search(r'(files = \([^)]*?\);.*?name = Sources;)', content, re.DOTALL)
    files_end = sources_section.group(1).find(");")
    new_sources_section = (sources_section.group(1)[:files_end] + 
                          "\n" + "\n".join(new_source_entries) + "\n" +
                          sources_section.group(1)[files_end:])
    content = content.replace(sources_section.group(1), new_sources_section)
    
    # Write the updated content
    with open(project_path, 'w') as f:
        f.write(content)
    
    print(f"Added {len(missing_files)} files to the project:")
    for file_path in missing_files:
        print(f"  - {file_path}")

def main():
    print("Analyzing project files...")
    
    # Get files
    files_on_disk = get_files_on_disk()
    files_in_project = get_files_in_project()
    
    print(f"Found {len(files_on_disk)} Swift files on disk")
    print(f"Found {len(files_in_project)} Swift files in project")
    
    # Find missing files
    missing_files = []
    for file_path in files_on_disk:
        filename = os.path.basename(file_path)
        
        # Check if this file or its filename is already in the project
        if file_path not in files_in_project and filename not in [os.path.basename(f) for f in files_in_project]:
            missing_files.append(file_path)
    
    if not missing_files:
        print("All files are already in the project!")
        return
    
    print(f"\nFound {len(missing_files)} missing files:")
    for file_path in missing_files:
        print(f"  - {file_path}")
    
    # Add missing files
    print(f"\nAdding {len(missing_files)} files to the project...")
    add_files_to_project(missing_files)
    
    print("\nDone! All Swift files should now be included in the project.")

if __name__ == "__main__":
    main()
