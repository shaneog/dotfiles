#!/bin/bash

# Requires both iTunes and Spotify applications to be installed
NOW_PLAYING=$(osascript <<EOF
  set spotify_state to missing value
  set itunes_state to missing value

  set track_name to missing value
  set artist_name to missing value

  if application "Spotify" is running then
    tell application "Spotify"
      set spotify_state to (player state as text)
    end tell
  end if

  if application "iTunes" is running then
    tell application "iTunes"
      set itunes_state to (player state as text)
    end tell
  end if

  if spotify_state is equal to "playing" then
    tell application "Spotify"
      set track_name to name of current track as text
      set artist_name to artist of current track as text
    end tell
  end if

  if itunes_state is equal to "playing" then
    tell application "iTunes"
      set track_name to name of current track as text
      set artist_name to artist of current track as text
    end tell
  end if

  if track_name is equal to missing value then
    return ""
  else
    return "♫ " & track_name & " #[nobold]::#[bold] " & artist_name
  end if
EOF)

echo $NOW_PLAYING