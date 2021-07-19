#  iTunes Music Partitioner

Partitions your music

In action:

Main UI:

![main ui](main_ui.png)

Playlist Menu:

![playlist ui](sub_menu_playlist.png)

Song Menu:

![song ui](sub_menu_song.png)

File format:
The config file should be in `json`, change `all_songs_json` in `Constants.swift` to point to your file.

- It should have an array of playlists
- Each playlist contains an array of concerts (or tracks within a playlist)
- Each concert contains an array of partitions.

Example of the screenshot:
```json
[
  {
    "name": "Playlist 1",
    "concerts": [
      {
        "name": "Song 1",
        "songs": [
          {
            "name": "partition 1",
            "time": 10
          },
          {
            "name": "partition 2",
            "time": 100
          }
        ]
      }
    ]
  }
]
```
