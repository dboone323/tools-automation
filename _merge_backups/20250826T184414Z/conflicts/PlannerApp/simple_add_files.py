#!/usr/bin/env python3
"""
Simple script to add missing Swift files to Xcode project
"""

import os
import re
import subprocess
import uuid

# Change to project directory
os.chdir("/Users/danielstevens/Desktop/PlannerApp")

print("Starting file analysis...")

# Get all Swift files on disk
result = subprocess.run(
    ["find", ".", "-name", "*.swift", "-not", "-path", "./DerivedData/*"],
    capture_output=True,
    text=True,
)
files_on_disk = [
    f.replace("./", "") for f in result.stdout.strip().split("\n") if f.strip()
]
print(f"Found {len(files_on_disk)} Swift files on disk")

# Get files currently in project
project_path = "PlannerApp.xcodeproj/project.pbxproj"
with open(project_path, "r") as f:
    content = f.read()

file_pattern = r"path = ([^;]+\.swift);"
matches = re.findall(file_pattern, content)
files_in_project = [match.strip('"') for match in matches]
print(f"Found {len(files_in_project)} Swift files in project")

# Find missing files (filter out backup versions and tests for now)
missing_files = []
for file_path in files_on_disk:
    filename = os.path.basename(file_path)

    # Skip if already in project
    if file_path in files_in_project or filename in [
        os.path.basename(f) for f in files_in_project
    ]:
        continue

    # Skip backup versions and test files for now
    if any(
        suffix in filename
        for suffix in ["_Working", "_Final", "_Minimal", "_Simple", "_New", "Tests"]
    ):
        continue

    missing_files.append(file_path)

print(f"Found {len(missing_files)} core missing files to add:")
for f in missing_files:
    print(f"  - {f}")

if not missing_files:
    print("No missing files to add!")
    exit(0)

print("Adding files to project...")

# Generate UUIDs and entries for each missing file
new_build_files = []
new_file_refs = []
new_source_entries = []

for file_path in missing_files:
    filename = os.path.basename(file_path)

    # Generate UUIDs (24 characters, uppercase hex)
    file_ref_uuid = uuid.uuid4().hex.upper()[:24]
    build_file_uuid = uuid.uuid4().hex.upper()[:24]

    # Create entries
    build_file_entry = f"\t\t{build_file_uuid} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};"
    file_ref_entry = f'\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = "{file_path}"; sourceTree = "<group>"; }};'
    source_entry = f"\t\t\t\t{build_file_uuid} /* {filename} in Sources */,"

    new_build_files.append(build_file_entry)
    new_file_refs.append(file_ref_entry)
    new_source_entries.append(source_entry)

# Insert new build files
build_section = re.search(
    r"(/\* Begin PBXBuildFile section \*/.*?/\* End PBXBuildFile section \*/)",
    content,
    re.DOTALL,
)
if build_section:
    build_section_text = build_section.group(1)
    insertion_point = build_section_text.rfind("/* End PBXBuildFile section */")
    new_build_section = (
        build_section_text[:insertion_point]
        + "\n".join(new_build_files)
        + "\n\t\t"
        + build_section_text[insertion_point:]
    )
    content = content.replace(build_section.group(1), new_build_section)
    print("Added build file entries")

# Insert new file references
file_ref_section = re.search(
    r"(/\* Begin PBXFileReference section \*/.*?/\* End PBXFileReference section \*/)",
    content,
    re.DOTALL,
)
if file_ref_section:
    file_section_text = file_ref_section.group(1)
    insertion_point = file_section_text.rfind("/* End PBXFileReference section */")
    new_file_section = (
        file_section_text[:insertion_point]
        + "\n".join(new_file_refs)
        + "\n\t\t"
        + file_section_text[insertion_point:]
    )
    content = content.replace(file_ref_section.group(1), new_file_section)
    print("Added file reference entries")

# Insert new source entries
sources_section = re.search(
    r"(files = \([^)]*?\);.*?name = Sources;)", content, re.DOTALL
)
if sources_section:
    sources_text = sources_section.group(1)
    insertion_point = sources_text.find(");")
    new_sources_section = (
        sources_text[:insertion_point]
        + "\n"
        + "\n".join(new_source_entries)
        + "\n\t\t\t"
        + sources_text[insertion_point:]
    )
    content = content.replace(sources_section.group(1), new_sources_section)
    print("Added source build phase entries")

# Write the updated project file
with open(project_path, "w") as f:
    f.write(content)

print(f"Successfully added {len(missing_files)} files to the project!")
print("Files added:")
for file_path in missing_files:
    print(f"  ✓ {file_path}")

print("\nProject file updated successfully.")
