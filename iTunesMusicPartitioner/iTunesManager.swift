//
//  iTunesManager.swift
//  iTunesMusicPartitioner
//
//  Created by James on 7/5/21.
//  Copyright © 2021 James. All rights reserved.
//

import Foundation
import ScriptingBridge
import Cocoa

/**
 Restarts a song to avoid blank screen
 */
class iTunesManager : NSObject, NSMenuDelegate {
    var prev_state: String
    var cur_song_name: String
    var iTunesPlayer: iTunesApplication
    var toogleResume: Bool = false
    var toggleFit: Bool = true
    var allSongs: [String: Playlist] = [:] // will be added
    var curPlaying: Song?
    var songChanged: Selector
    var updateTimer: DispatchSourceTimer?
    var statusBarMenu: NSMenu?
    
    init(_ statusBarMenu: NSMenu, _ insertAfter: Int, _ songChanged: Selector) {
        self.prev_state = "Playing"
        self.cur_song_name = ""
        let running_apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iTunes")
        let pid = running_apps[0].processIdentifier
//        self.iTunesPlayer = SBApplication(bundleIdentifier: "com.launcher.iTunes")!
        self.iTunesPlayer = SBApplication(processIdentifier: pid)!
        self.songChanged = songChanged
        self.statusBarMenu = statusBarMenu
        super.init()

        allSongs = addAllSongs(parent: statusBarMenu, insertAfter)
        startObserving()
        
        NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { (event) in
            let f16: UInt16 = 106
            let f15: UInt16 = 113
            let f14: UInt16 = 107
            
            print(event.keyCode)

            switch (event.keyCode) {
                case f16:
                    self.play_next()
                    break
                case f15:
                    self.restart_current()
                    break
                case f14:
                    self.play_prev()
                    break
                default:
                    break
            }
        }
    }
    
    deinit {
        for (_, playlists) in allSongs {
            statusBarMenu?.removeItem(playlists.menu)
        }
    }
    
    func updateCurPlaying() {
        let last = curPlaying
        curPlaying = current_song()
        
        guard (last?.name == curPlaying?.name
            && last?.concertName == curPlaying?.concertName
            && last?.playlistName == curPlaying?.playlistName)
        else {
            clearCurPlaying(song: last)
            markCurPlaying()
            return
        }
    }
    
    func startUpdateTimer() {
        print("Start updating every \(updateInterval) seconds")
        updateTimer = nil
        let queue = DispatchQueue(label: "com.domain.app.timer")
        updateTimer = DispatchSource.makeTimerSource(queue: queue)
        updateTimer?.schedule(deadline: .now(), repeating: .seconds(updateInterval))
        updateTimer?.setEventHandler { [self] in
            self.updateCurPlaying()
        }
        updateTimer?.resume()
    }
    
    func stopUpdateTimer() {
        print("Stop updating")
        updateTimer = nil
    }
    
    func menuWillOpen(_ menu: NSMenu) {
        startUpdateTimer()
    }
    
    func menuDidClose(_ menu: NSMenu) {
        stopUpdateTimer()
    }
    
    /**
     Tell the main menu to update the song display
     */
    func updateDisplay(playing: Song?) {
        DispatchQueue.main.async {
            NSApp.delegate?.perform(self.songChanged, with: playing)
        }
    }
    
    /**
     Mark or clear the currently playing song in the menu given a state
     */
    func displayCurPlaying(song: Song?, state: NSControl.StateValue) {
        guard
            let playing = song,
            let curPlaylist = allSongs[playing.playlistName],
            let curConcert = curPlaylist.concerts[playing.concertName]
        else {
            updateDisplay(playing: nil)
            return
        }
        let curSong = curConcert.songs[playing.idx] // does not include the "Intro"
        curPlaylist.menu.state = state
        curConcert.menu.state = state
        curSong.state = state
        updateDisplay(playing: playing)
        
    }

    /**
     Clears the currently playing song in the menu
     */
    func clearCurPlaying(song: Song?) {
        displayCurPlaying(song: song, state: .off)
    }
    
    /**
     Marks the currently playing song in the menu
     */
    func markCurPlaying() {
        displayCurPlaying(song: curPlaying, state: .on)
    }
    
    /**
     Play this song by index, useful for navigating the song
     */
    func play_song(playlistName: String, concertName: String, index i: Int) {
        guard
            i >= 0,
            let playlist = allSongs[playlistName],
            let concert = playlist.concerts[concertName],
            i < concert.songs.count // the first one is play all, so we have one more than actual
        else {
            return
        }

        let time = concert.songs[i].time
        play_song(playlistName: playlistName, concertName: concertName, time: time)
    }

    func send_enter() {
        let running_apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iTunes")
        let pid = running_apps[0].processIdentifier
        let enter: UInt16 = 0x24
        let src = CGEventSource(stateID: .hidSystemState)
        let keydown = CGEvent(keyboardEventSource: src, virtualKey: enter, keyDown: true)
        let keyup = CGEvent(keyboardEventSource: src, virtualKey: enter, keyDown: false)
        keydown?.postToPid(pid)
        keyup?.postToPid(pid)
    }

    /**
     Play this song given all the details
     */
    func play_song(playlistName: String, concertName: String, time t: Int) {
        guard
            let playlist = find_itunes_playlist(playlistName: playlistName),
//            let playlistPlay = playlist.playOnce,
            let getTracks = playlist.tracks,
//            let stop = iTunesPlayer.stop,
            let curTrackIdx = iTunesPlayer.currentTrack?.index,
            let track_tobe_played = find_itunes_concert(concertName: concertName, playlist: playlist),
            let concertIdx = track_tobe_played.index,
            let revealTrack = track_tobe_played.reveal,
            let setPlayerPosition = iTunesPlayer.setPlayerPosition,
            let play = iTunesPlayer.playpause,
            let playerState = iTunesPlayer.playerState
        else {
            return
        }

        let tracks = getTracks() as! [iTunesTrack]

        guard
            concertIdx <= tracks.count
        else {
            return
        }

        if curTrackIdx != concertIdx {
            revealTrack()
            send_enter()
        }
        // if the current song is the playing one, just set the time
        setPlayerPosition(Double(t))
        if (playerState != .playing) {
            play()
        }
        // the song might not be the right size, we try to fit it
        if (toggleFit) {
            // there might be lag when a music started
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fit_to_screen()
            }
        }
    }
    
    /**
     Play the previous song, if there is any
     */
    func play_prev() {
        curPlaying = current_song()
        guard
            let playing = curPlaying
        else {
            return
        }
        play_song(
            playlistName: playing.playlistName,
            concertName: playing.concertName,
            index: playing.idx - 1
        ) // idx starts with 1, but our list starts with 0,
    }
    
    /**
     Play the next song, if there is any
     */
    func play_next() {
        curPlaying = current_song()
        guard
            let playing = curPlaying
        else {
            return
        }
        play_song(
            playlistName: playing.playlistName,
            concertName: playing.concertName,
            index: playing.idx + 1
        ) // idx starts with 1, but our list starts with 0
    }
    

    /**
     Play the current song from the start, if there is any
     */
    func restart_current() {
        curPlaying = current_song()
        guard
            let playing = curPlaying
        else {
            return
        }
        play_song(
            playlistName: playing.playlistName,
            concertName: playing.concertName,
            index: playing.idx
        ) // idx starts with 1, but our list starts with 0
    }

    /**
     Get the currently playing song (song within a concert, not current track)
     index will start from one
     */
    func current_song() -> Song? {
        // convert current timestamp to song index
        
        guard let cur_playlist = iTunesPlayer.currentPlaylist        else {return nil}
        guard let cur_playlist_name = cur_playlist.name              else {return nil}
        guard let playlist = allSongs[cur_playlist_name]             else {return nil}
        guard let position = iTunesPlayer.playerPosition             else {return nil}
        guard let cur_concert_name = iTunesPlayer.currentTrack?.name else {return nil}
        guard let cur_concert = playlist.concerts[cur_concert_name]  else {return nil}

        let time = Int(position)
        var last: Song? = nil
        for song in cur_concert.songs {
            guard song.time <= time else {
                // the last song before this time
                print("Now playing: \(last!.idx) \(last!.name), \(last!.concertName), \(last!.playlistName)")
                return last
            }
            last = song
        }
        // must be the last one
        return cur_concert.songs[cur_concert.songs.endIndex - 1]
    }
    
    /**
        find a track in a playlist given its name, with cache
     */
    func find_itunes_concert(concertName: String, playlist: iTunesPlaylist) -> iTunesTrack? {
        guard
            let playlistName = playlist.name,
            let getTracks = playlist.tracks,
            var concert = allSongs[playlistName]?.concerts[concertName]
        else {
            return nil
        }
        let tracks = getTracks() as! [iTunesTrack] // we know it has to be this
        guard
            let idx = concert.iTunesIdx
        else {
            // cache not found
            for (i, track) in tracks.enumerated() {
                guard track.name != concertName else {
                    concert.iTunesIdx = i // store cache
                    return track
                }
            }
            return nil
        }
        // cache found
        return tracks[idx]
    }
    
    /**
     Finds the playlist in itunes by name, or from cache
     */
    func find_itunes_playlist(playlistName: String) -> iTunesPlaylist? {
        guard
            let getPlaylists = iTunesPlayer.playlists
        else {
            return nil
        }
        let playlists = getPlaylists() as! [iTunesPlaylist] // we know it has to be this

        guard
            let idx = allSongs[playlistName]?.iTunesIdx
        else {
            // cache not found
            for (i, playlist) in playlists.enumerated() {
                guard playlist.name != playlistName else {
                    allSongs[playlistName]?.iTunesIdx = i // store cache
                    return playlist
                }
            }
            // playlist not found
            return nil
        }
        // cache found
        return playlists[idx]
    }
    
    func getWindowTitle(_ window: AXUIElement) -> String? {
        var titleRef: AnyObject?
        let err = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        guard err == .success else {
            return nil
        }
        return titleRef as? String
    }
    
    func setWindowBounds(_ window: AXUIElement, x: Int, y: Int, width: Int, height: Int) {
        var point = CGPoint(x: x, y: y)
        let position = AXValueCreate(
            AXValueType(rawValue: kAXValueCGPointType)!,
            &point
        )!
        let pos_err = AXUIElementSetAttributeValue(
            window,
            kAXPositionAttribute as CFString,
            position
        )
        if pos_err != .success {
            print(pos_err)
            return
        }
        var rect = CGSize(width: width, height: height)
        let size = AXValueCreate(
            AXValueType(rawValue: kAXValueCGSizeType)!,
            &rect
        )!
        let size_err = AXUIElementSetAttributeValue(
            window,
            kAXSizeAttribute as CFString,
            size
        )
        if size_err != .success {
            print(size_err)
            return
        }
    }

    func getWindowSize(windowRef: AXUIElement) -> CGSize? {
        var sizeRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            windowRef,
            kAXSizeAttribute as CFString,
            &sizeRef
        )
        guard err == .success else {
            print(err.rawValue)
            return nil
        }
        var size: CGSize = CGSize()
        let success = AXValueGetValue(
            sizeRef as! AXValue,
            AXValueType(rawValue: kAXValueCGSizeType)!,
            &size
        )
        if !success {
            print("Failed to convert size data")
            return nil
        }

        return size
    }

    func getWindowPosition(windowRef: AXUIElement) -> CGPoint? {
        var positionRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(
            windowRef,
            kAXPositionAttribute as CFString,
            &positionRef
        )
        guard err == .success else {
            print(err.rawValue)
            return nil
        }
        var position: CGPoint = CGPoint()
        let success = AXValueGetValue(
            positionRef as! AXValue,
            AXValueType(rawValue: kAXValueCGPointType)!,
            &position
        )
        if !success {
            print("Failed to convert position data")
            return nil
        }

        return position
    }

    func get_ax_window() -> AXUIElement? {
        // get the ax window to set bounds
        let running_apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.iTunes")
        let pid = running_apps[0].processIdentifier
        // get handle
        let ui_app = AXUIElementCreateApplication(pid)
        var value: AnyObject?
        let err = AXUIElementCopyAttributeValue(
            ui_app,
            kAXWindowsAttribute as CFString,
            &value
        ) as AXError

        guard err == .success else {
//            notification(title: "Error getting iTunes window", text: "\(err)")
            print(err.rawValue)
            return nil
        }
        // filter window with this name
        guard
            let windows = value as? [AXUIElement],
            windows.count > 0
        else {
            print("No windows found for itunes")
            return nil
        }
        // filter window that is not iTunes, then it must be the music
        let non_itunes_windows = windows.filter { window in
            return getWindowTitle(window) != "iTunes"
        }
        guard non_itunes_windows.count > 0 else {
            print("No music window")
            return nil
        }
        return non_itunes_windows[0]
    }

    func fit_x(_ cur_width: Int) -> Int {
        // this is where x should be fitted
        // difference between their mid point
        let width_diff = (-1024 + Int(cur_width)) / 2
        return -1075 - width_diff
    }

    func fit_y(_ cur_height: Int) -> Int {
        // this is where x should be fitted
        // difference between their mid point
        let height_diff = (745 - Int(cur_height)) / 2
        return 1463 + height_diff
    }

    func fit_to_screen() {
        guard let window = get_ax_window() else { return }
        guard var size = getWindowSize(windowRef: window) else { return }
        guard let pos = getWindowPosition(windowRef: window) else { return }
        // check diff to see if it's already fitted
        if fit_x(Int(size.width)) - Int(pos.x) <= 5 && fit_y(Int(size.height)) - Int(pos.y) <= 5 {
            print("Already fitted within error")
            return
        }
        // first we go to the top right corner, expand the window
        setWindowBounds(
            window,
            x: -1075,
            y: 1463,
            width: 1024,
            height: 745
        )
        // then we get the actual size, then move to the middle
        size = getWindowSize(windowRef: window)!

        // screen left: -1075, screen right: -51
        // screen top: 1463, screen bottom: 2208 (minus the top status bar)
        setWindowBounds(
            window,
            x: fit_x(Int(size.width)),
            y: fit_y(Int(size.height)),
            width: Int(size.width),
            height: Int(size.height)
        )
    }
    
    /**
     Resumes the video playback with video
     
     Before Monterey, if you play the same video again, the video will go blank but with sound
     Call this to resume the video playback
     */
    @objc func resume() {
        // resumes the playback with video
        guard
            let trackIdx = iTunesPlayer.currentTrack?.index,
            let playlistName = iTunesPlayer.currentPlaylist?.name,
            let playlist = find_itunes_playlist(playlistName: playlistName),
            let curTrack = playlist.tracks?()[trackIdx - 1] as? iTunesTrack,
            let stop = iTunesPlayer.stop,
            let play = curTrack.playOnce,
            let time = iTunesPlayer.playerPosition,
            let setPlayerPosition = iTunesPlayer.setPlayerPosition
            // the currentTrack will change if we stop the playback, so must get the absolute reference
        else {
            return
        }
        
        guard curTrack.videoKind == .musicVideo else { return }

        print("Resuming")
        // the trick is, stop and play the same thing again ...
        stop()
        play(false)
        setPlayerPosition(time)
    }
    
    /**
     When the play state of current music changes, determine whether we need to resume the video playback
     */
    @objc func observeMusic(_ n: NSNotification) {
        if (toggleFit) {
            // there might be lag when a music started
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.fit_to_screen()
            }
        }
        let cur_state = n.userInfo?["Player State"] as! String
        if cur_state == "Playing" {
            let song = n.userInfo?["Name"] as? String
            if song != cur_song_name {
                cur_song_name = song!
                return
            }
        }
        let shouldResume = prev_state == "Playing" && cur_state == "Playing"
        self.prev_state = cur_state

        if (shouldResume && toogleResume) {
            resume()
        }
    }
    
    func startObserving() {
        // observe song change
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(observeMusic),
            name: NSNotification.Name.init("com.apple.iTunes.playerInfo"),
            object: "com.apple.iTunes.player"
        )
        updateCurPlaying()
    }
}
