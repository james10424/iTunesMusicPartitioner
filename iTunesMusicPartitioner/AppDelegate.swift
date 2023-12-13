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
    var itemsBeforeSongs: Int!
    var window: NSWindow!
    var statusBarItem: NSStatusItem!
    var itunes_manager: iTunesManager!
    var should_repeat: Bool = true
    var statusBarMenu: NSMenu?
    var curPlaylist: NSMenuItem?
    var curConcert: NSMenuItem?
    var curSong: NSMenuItem?
    var prevBtn: NSMenuItem?
    var nextBtn: NSMenuItem?
    var replayBtn: NSMenuItem?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        statusBarMenu = NSMenu()

        let statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        statusBarItem.button?.title = titleText
        statusBarItem.menu = statusBarMenu
        
        // cur playing section
        curPlaylist = NSMenuItem(
            title: notPlayingText, action: nil, keyEquivalent: ""
        )
        statusBarMenu!.addItem(curPlaylist!)
        curConcert = NSMenuItem(
            title: notPlayingText, action: nil, keyEquivalent: ""
        )
        statusBarMenu!.addItem(curConcert!)
        curSong = NSMenuItem(
            title: notPlayingText, action: nil, keyEquivalent: ""
        )
        statusBarMenu!.addItem(curSong!)

        statusBarMenu!.addItem(NSMenuItem.separator())
        
        // control section
        let fit_to_screen = NSMenuItem(
            title: "Fit to Screen",
            action: #selector(AppDelegate.toggle_fit),
            keyEquivalent: ""
        )
        fit_to_screen.state = .on // on by default
        statusBarMenu!.addItem(fit_to_screen)


        let repeat_video = NSMenuItem(
            title: "Repeat wtih video",
            action: #selector(AppDelegate.toggle_repeat),
            keyEquivalent: ""
        )
        repeat_video.state = .off // off by default
        statusBarMenu!.addItem(repeat_video)

        statusBarMenu!.addItem(
            withTitle: "Do \"Fit to Screen\"",
            action: #selector(AppDelegate.fit_to_screen),
            keyEquivalent: ""
        )

        statusBarMenu!.addItem(
            withTitle: "Resume",
            action: #selector(AppDelegate.resume),
            keyEquivalent: "r"
        )
        
        prevBtn = NSMenuItem(
            title: prevText,
            action: #selector(AppDelegate.prev),
            keyEquivalent: "a"
        )
        statusBarMenu!.addItem(prevBtn!)

        replayBtn = NSMenuItem(
            title: replayText,
            action: #selector(AppDelegate.replay),
            keyEquivalent: "w"
        )
        statusBarMenu!.addItem(replayBtn!)
        
        nextBtn = NSMenuItem(
            title: nextText,
            action: #selector(AppDelegate.next),
            keyEquivalent: "d"
        )
        statusBarMenu!.addItem(nextBtn!)
        
        statusBarMenu!.addItem(NSMenuItem.separator())
        
        itemsBeforeSongs = statusBarMenu!.items.count
        
        itunes_manager = iTunesManager(
            statusBarMenu!,
            itemsBeforeSongs!,
            #selector(AppDelegate.songChanged)
        ) // song menus will be added inside

        statusBarMenu!.addItem(NSMenuItem.separator())
        statusBarMenu!.addItem(withTitle: "Configure", action: #selector(AppDelegate.reload_config), keyEquivalent: "")
        statusBarMenu!.addItem(withTitle: "Quit", action: #selector(AppDelegate.quit), keyEquivalent: "q")
        
        itunes_manager.startObserving()
        statusBarItem.menu?.delegate = itunes_manager
        checkPermission()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func checkPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String : true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessEnabled {
            print("Access Not Enabled")
        }
        else {
            print("Access Enabled")
        }
    }

    @objc func songChanged(playing: Song?) {
        guard let curPlaying = playing else {
            curPlaylist?.title = "No Playlist"
            curConcert?.title = "No Concert"
            curSong?.title = "Not Playing"
            prevBtn?.title = "\(prevText)"
            nextBtn?.title = "\(nextText)"
            replayBtn?.title = "\(replayText)"
            return
        }
        // set cur song display
        curPlaylist?.title = curPlaying.playlistName
        curConcert?.title = curPlaying.concertName
        curSong?.title = curPlaying.name
        
        // set prev and next
        let cur_idx = curPlaying.idx
        guard
            let curConcertSongs = itunes_manager.allSongs[curPlaying.playlistName]?.concerts[curPlaying.concertName]?.songs
        else {
            return
        }
        if cur_idx > 0 {
            prevBtn!.title = "\(prevText) \(curConcertSongs[cur_idx - 1].name)"
        }
        else {
            prevBtn!.title = "\(prevText)"
        }
        if cur_idx + 1 < curConcertSongs.count {
            nextBtn!.title = "\(nextText) \(curConcertSongs[cur_idx + 1].name)"
        }
        else {
            nextBtn!.title = "\(nextText)"
        }
        replayBtn!.title = "\(replayText) \(curPlaying.name)"
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
    
    @objc func toggle_fit(_ sender: NSMenuItem) {
        if itunes_manager.toggleFit {
            sender.state = .off
        }
        else {
            sender.state = .on
        }
        itunes_manager.toggleFit = !itunes_manager.toggleFit
    }
    
    @objc func prev() {
        print("Playing prev")
        itunes_manager.play_prev()
    }

    @objc func replay() {
        print("Replaying current")
        itunes_manager.restart_current()
    }
    
    @objc func next() {
        print("Playing next")
        itunes_manager.play_next()
    }

    @objc func quit() {
        NSApplication.shared.terminate(self)
    }
    
    @objc func resume() {
        itunes_manager.resume()
    }
    
    @objc func fit_to_screen() {
        itunes_manager.fit_to_screen()
    }
    
    @objc func play(w: Song) {
        itunes_manager.play_song(playlistName: w.playlistName, concertName: w.concertName, time: w.time)
    }
    
    @objc func reload_config() {
        guard
            let menu = statusBarMenu,
            let songs = readConfig(selectFile: true)
        else { return }
        all_songs_json = songs
        itunes_manager = iTunesManager(
            menu,
            itemsBeforeSongs,
            #selector(AppDelegate.songChanged)
        ) // song menus will be added inside
        statusBarItem.menu?.delegate = itunes_manager
    }
}

