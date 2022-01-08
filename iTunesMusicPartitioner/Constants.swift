//
//  Constants.swift
//  iTunesMusicPartitioner
//
//  Created by James on 7/5/21.
//  Copyright © 2021 James. All rights reserved.
//

import Foundation
import Cocoa

// representation of the library, with menu attached to each
struct Concert {
    let name: String
    let songs: [Song]
    let menu: NSMenuItem
    var iTunesIdx: Int?
}
struct Playlist {
    let name: String
    let concerts: [String: Concert]
    let menu: NSMenuItem
    var iTunesIdx: Int?
}

struct JSONSongs: Decodable {
    let name: String
    let time: Int
}
struct JSONConcert: Decodable {
    let name: String
    let songs: [JSONSongs]
}
struct JSONPlaylist: Decodable {
    let name: String
    let concerts: [JSONConcert]
}

/**
 Reads the song list from a file name
 
 The file must be in a valid JSON format and
 the schema of the JSON must look like this:
 {
    "playlistName1": {
        "concertName1": [
            {"name": "songName", "time": 10}
        ],
        "concertName2": [
            {"name": "songName", "time": 100}
        ],
    },
    "playlistName2": {
         "concertName1": [
             {"name": "songName", "time": 5}
         ],
         concertName2: [
             {"name": "songName", "time": 13}
         ],
    },
    ...
 }
 */
func read_songs(fname: String) -> [JSONPlaylist]? {
    var content: String
    do {
        content = try String(contentsOfFile: fname)
    } catch {
        print("Error reading file: \(error)")
        return nil
    }
    guard
        let data = content.data(using: .utf8)
    else {
        print("Failed to read song file")
        return nil
    }
    do {
        let json_output = try JSONDecoder().decode([JSONPlaylist].self, from: data)
        print(json_output)
        return json_output
    } catch {
        print("error parsing songs: \(error)")
        return nil
    }
}

/**
 Displays a dialog, optional handler to handle what happens with the window and key press
 */
func notification(title: String, text: String, handler: ((NSAlert) -> Void)? = nil) {
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = text
    alert.alertStyle = .warning

    if handler != nil {
        handler!(alert)
    }
    else {
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

/**
 Ask for a file path, optional pre-selected file
 
 Return the file name if successful
 */
func askForFile(defaultFile: String?) -> String? {
    let dialog = NSOpenPanel()
    dialog.message = "Choose a music config file (json)"
    dialog.showsResizeIndicator = true
    dialog.showsHiddenFiles = false
    dialog.allowsMultipleSelection = false
    dialog.canChooseDirectories = false
    dialog.allowedFileTypes = ["json"]
    if defaultFile != nil {
        dialog.directoryURL = NSURL.fileURL(withPath: defaultFile!)
    }
    if dialog.runModal() == .OK {
        return dialog.url?.path
    }
    return nil
}

/**
 Reads the config from storage, or select a new file. If no previously saved storage, select a new file
 
 returns the object read if success
 
 The config has the following format:
 [
    {
        "name": "window name",
        "x": 2561,
        "y": -1093,
        "width": 1079,
        "height": 614
    },
    ...
 ]
 */
func readConfig(selectFile: Bool) -> [JSONPlaylist]? {
    let defaults = UserDefaults.standard
    var fname: String?
    let defaultFile = defaults.string(forKey: "songConfig")
    if selectFile || defaultFile == nil {
        fname = askForFile(defaultFile: defaultFile)
    }
    else {
        fname = defaultFile
    }
    guard fname != nil else {
        notification(title: "This doesn't work", text: "You haven't selected a file")
        return nil
    }
    guard let songs = read_songs(fname: fname!) else {
        notification(title: "Invalid config", text: "The config file you supplied is invalid")
        return nil
    }
    defaults.set(fname, forKey: "songConfig")
    return songs
}

var all_songs_json = readConfig(selectFile: false) //read_songs(fname: "/Users/james/applescripts/songs.json")

let titleText = "♫"
let prevText = "←"
let replayText = "⟳"
let nextText = "→"
let notPlayingText = "Not Playing"

let updateInterval = 5 // update every x seconds
