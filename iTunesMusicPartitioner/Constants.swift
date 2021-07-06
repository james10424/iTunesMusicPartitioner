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
func read_songs(fname: String) -> [String: [String: [AnyObject]]]? {
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
        let json_output = try JSONSerialization.jsonObject(with: data, options: [])
        print(json_output)
        return (json_output as! [String: [String: [AnyObject]]])
    } catch {
        print("error parsing songs: \(error)")
        return nil
    }
}

let all_songs_json = read_songs(fname: "/Users/james/applescripts/songs.json")

let titleText = "♫"

let updateInterval = 5 // update every x seconds
