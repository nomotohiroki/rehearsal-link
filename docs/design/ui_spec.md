# UI/UX Design Specification

## Overview
This document outlines the visual design and user experience for the RehearsalLink application, based on the design prototype generated via Stitch.

## Design Reference
- **Stitch Project Name:** RehearsalLink
- **Project ID:** `projects/3675309198597456863`
- **Main Screen ID:** `5f8616cd86ef4c13934b1e82ba987f58`

## Theme
- **Style:** Modern, Professional Audio Tool (DAW-like).
- **Color Mode:** Dark Mode.
- **Accent Colors:**
  - Music Segments: Blue
  - Speech Segments: Green
  - Selection/Active: System Accent (Blue/Vibrant)

## Layout Structure

### 1. Header / Toolbar
- **Position:** Top
- **Items:**
  - "Open Audio" button (Icon: `music.note.list`)
  - "Open Project" button (Icon: `folder`)
  - "Save" button (Icon: `square.and.arrow.down`)

### 2. Main Workspace (Waveform)
- **Position:** Center / Leading
- **Components:**
  - **Waveform Visualization:** High-contrast waveform rendering.
  - **Segment Overlays:** Colored regions overlaying the waveform to indicate "Music" or "Speech".
  - **Playhead:** Vertical line indicating current playback position.
  - **Interactions:**
    - Click to seek.
    - Drag segment boundaries to resize.
    - Context menu or click to select segments.

### 3. Transport Bar
- **Position:** Bottom
- **Components:**
  - Play / Pause Toggle
  - Stop Button
  - Time Display (format `MM:SS.ss`)
  - "Split Segment" Tool (Icon: `scissors`)

### 4. Inspector Panel
- **Position:** Right Side (Collapsible/Persistent)
- **Purpose:** Edit details of the currently selected segment.
- **Fields:**
  - **Start Time:** Editable text field.
  - **End Time:** Editable text field.
  - **Segment Type:** Dropdown/Picker (Music, Speech, Silence).
