//
//  Song.swift
//  iTunesMusicPartitioner
//
//  Created by James on 7/5/21.
//  Copyright © 2021 James. All rights reserved.
//

import Foundation
import Cocoa

class Song : NSMenuItem {
    let name: String
    let time: Int
    let idx: Int
    let concertName: String
    let playlistName: String

    init(
        action selector: Selector?,
        keyEquivalent charCode: String,
        songName: String,
        songTime: Int,
        songIdx: Int,
        concertName: String,
        playlistName: String
    ) {
        self.time = songTime
        self.concertName = concertName
        self.playlistName = playlistName
        self.name = songName
        self.idx = songIdx
        super.init(title: String(songIdx) + " - " + name, action: selector, keyEquivalent: charCode)
    }
    
    required init(coder: NSCoder) {
        self.time = -1
        self.concertName = ""
        self.playlistName = ""
        self.name = ""
        self.idx = -1
        super.init(coder: coder)
    }
}

/**
    adds a sub menu with list of items, assumes `dropdownItem` will be added to the menu somewhere else
 
 - Parameter dropdownItem : the dropdown menu item
 - Parameter items: the menu items inside this menu
 */
func addSubMenu(_ dropdownItem: NSMenuItem, _ items: [NSMenuItem]) {
    let dropdownMenu = NSMenu()
    for item in items {
        dropdownMenu.addItem(item)
    }
    dropdownItem.submenu = dropdownMenu
}

/**
    adds a sub menu with list of items
 
 - Parameter parent : the parent menu
 - Parameter title: the title of this sub menu
 - Parameter items: the menu items inside this menu
 */
func addSubMenu(_ parent: NSMenu, _ title: String, _ items: [NSMenuItem]) -> NSMenuItem {
    let dropdownItem = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    addSubMenu(dropdownItem, items)
    parent.addItem(dropdownItem)
    return dropdownItem
}

/**
    Adds a concert to the menu
 - Parameter parent: the parent menu
 - Parameter playlistName: the name of the playlist
 - Parameter concertIdx: the index of the concert within iTunes
 - Parameter concert: the concert to add
*/
func addConcert(
    parent: NSMenuItem,
    playlistName: String,
    concertName: String,
    songs: [JSONSongs]
) -> Concert {
    var menu_items: [Song] = []
    var _songs: [Song] = []
    
    // add default play
    let play = Song(
        action: #selector(AppDelegate.play),
        keyEquivalent: "",
        songName: "Intro",
        songTime: 0,
        songIdx: 0,
        concertName: concertName,
        playlistName: playlistName
    ) // to be filled
    
    menu_items.append(play)
    _songs.append(play)
    
    for (i, song) in songs.enumerated() {
        let item = Song(
            action: #selector(AppDelegate.play),
            keyEquivalent: "",
            songName: song.name,
            songTime: song.time,
            songIdx: i + 1,
            concertName: concertName,
            playlistName: playlistName
        )
        menu_items.append(item)
    }
    addSubMenu(parent, menu_items)

    return Concert(name: concertName, songs: menu_items, menu: parent)
}

/**
    Adds a playlist to the menu
 - Parameter statusBarMenu: the menu object
 - Parameter playlist: the playlist to add
*/
func addPlaylist(
    parent statusBarMenu: NSMenu,
    playlistName: String,
    concerts: [JSONConcert]
) -> Playlist {
    var concertMappings: [String: Concert] = [:]
    var concertMenus: [NSMenuItem] = []
    
    concerts.forEach { concert in
        let concertName = concert.name
        let songs = concert.songs

        print("Creating menu for concert \(concertName)")

        let concertMenu = NSMenuItem(
            title: concertName,
            action: nil,
            keyEquivalent: ""
        )
        // concert index + 1 because itunes starts at 1
        let concertItems = addConcert(
            parent: concertMenu,
            playlistName: playlistName,
            concertName: concertName,
            songs: songs
        )
        concertMappings[concertName] = concertItems
        concertMenus.append(concertMenu)
    }
    
    let playlistMenu = addSubMenu(statusBarMenu, playlistName, concertMenus)

    return Playlist(name: playlistName, concerts: concertMappings, menu: playlistMenu)
}

func addAllSongs(
    parent statusBarMenu: NSMenu
) -> [String: Playlist] {
    // adds all songs to menu and return the mapping
    print("All songs:", all_songs_json as Any)
    var song_mappings: [String: Playlist] = [:]
    for playlist in all_songs_json ?? [] {
        let playlistName = playlist.name
        let concerts = playlist.concerts
        print("Creating menu for playlist \(playlistName)")
        let mapping = addPlaylist(
            parent: statusBarMenu,
            playlistName: playlistName,
            concerts: concerts
        )
        song_mappings[playlistName] = mapping
    }
    return song_mappings
}
