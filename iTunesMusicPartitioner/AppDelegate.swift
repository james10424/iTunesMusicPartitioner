//
//  AppDelegate.swift
//  iTunesMusicPartitioner
//
//  Created by James on 7/5/21.
//  Copyright © 2021 James. All rights reserved.
//

import Cocoa
import Foundation
import SwiftUI

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var window: NSWindow!
    var statusBarItem: NSStatusItem!
    var itunes_manager: iTunesManager!
    var should_repeat: Bool = true
    
    var curPlaylist: NSMenuItem?
    var curConcert: NSMenuItem?
    var curSong: NSMenuItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let statusBarMenu = NSMenu()

        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.title = titleText
        statusBarItem.menu = statusBarMenu

        curPlaylist = NSMenuItem(
            title: "Not Playing", action: nil, keyEquivalent: ""
        )
        statusBarMenu.addItem(curPlaylist!)
        curConcert = NSMenuItem(
            title: "Not Playing", action: nil, keyEquivalent: ""
        )
        statusBarMenu.addItem(curConcert!)
        curSong = NSMenuItem(
            title: "Not Playing", action: nil, keyEquivalent: ""
        )
        statusBarMenu.addItem(curSong!)
        
        statusBarMenu.addItem(NSMenuItem.separator())
        
        let repeat_video = NSMenuItem(title: "Repeat wtih video",
                                      action: #selector(AppDelegate.toggle_repeat),
                                      keyEquivalent: "")
        repeat_video.state = .on // on by default
        statusBarMenu.addItem(repeat_video)
        
        statusBarMenu.addItem(withTitle: "Resume",
                              action: #selector(AppDelegate.resume),
                              keyEquivalent: "r")
        
        statusBarMenu.addItem(withTitle: "←Previous",
                              action: #selector(AppDelegate.prev),
                              keyEquivalent: "a")
        
        statusBarMenu.addItem(withTitle: "→Next",
                              action: #selector(AppDelegate.next),
                              keyEquivalent: "d")
        
        itunes_manager = iTunesManager(
            statusBarMenu,
            #selector(AppDelegate.songChanged)
        ) // song menus will be added inside

        statusBarMenu.addItem(NSMenuItem.separator())
        statusBarMenu.addItem(withTitle: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        
        itunes_manager.startObserving()
        statusBarItem.menu?.delegate = itunes_manager
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    @objc func songChanged(playing: Song?) {
        guard let curPlaying = playing else {
            curPlaylist?.title = "No Playlist"
            curConcert?.title = "No Concert"
            curSong?.title = "Not Playing"
            return
        }
        print("Now playing: \(curPlaying.name)")
        curPlaylist?.title = curPlaying.playlistName
        curConcert?.title = curPlaying.concertName
        curSong?.title = curPlaying.name
    }

    @objc func toggle_repeat(_ sender: NSMenuItem) {
        if itunes_manager.toogleResume {
            sender.state = .off
        }
        else {
            sender.state = .on
        }
        itunes_manager.toogleResume = !itunes_manager.toogleResume
    }
    
    @objc func prev() {
        itunes_manager.play_prev()
    }
    
    @objc func next() {
        itunes_manager.play_next()
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    
    @objc func resume() {
        itunes_manager.resume()
    }
    
    @objc func play(w: Song) {
        itunes_manager.play_song(playlistName: w.playlistName, concertName: w.concertName, time: w.time)
    }
}

