#  iTunes Music Partitioner

Partitions your music

In action:


File format:
The config file should be in `json`

- It should have an array of playlists
```json
[
  {
    "name": "Playlist 1",
    "concerts": [ ... ]
  }
]
```
- Each playlist contains an array of concerts (or tracks within a playlist)
```json
[
  {
    "name": "Playlist 1",
    "concerts": [
      {
        "name": "Song 1",
        "songs": [ ... ]
      }
    ]
  }
]
```

- Each concert contains an array of partitions.
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
```
