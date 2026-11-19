# Virtual Android machines

Husk's front end is a machine manager in the shape of Virtual Master: a list of
Android phones, each with its own version and data, instead of one hidden guest
shared by every app. The QEMU engine underneath is unchanged. This document
describes the manager's model, where its files live, and what it can and cannot
do.

## The catalogue

`AndroidRelease` in `src/app/Husk/VirtualMachine.swift` is a shape Husk knows how
to boot: an Android version, API level, screen defaults, minimum RAM, and whether
the image is the one shipped by Husk.

| Release | API | Built in |
|---|---:|---|
| Android 4.4 KitKat | 19 | no |
| Android 5.1 Lollipop | 22 | no |
| Android 6.0 Marshmallow | 23 | no |
| Android 7.1 Nougat | 25 | no |
| Android 8.1 Oreo | 27 | no |
| Android 9 Pie | 28 | no |
| Android 10 | 29 | no |
| Android 11 | 30 | no |
| Android 12 | 31 | no |
| Android 13 Tiramisu | 33 | **yes** |
| Android 14 | 34 | no |

A release is listed because the manager can build a machine for it, not because
a download for it exists. Only Android 13 has a hosted image. The other rows are
enabled once a compatible disk has been imported for that release.

## A machine

`VirtualMachine` is the persisted record. It contains:

- `id` and display `name`
- `releaseID` and the release's defaults
- `systemImagePath` — the shared, read-only-from-Android system disk
- `userdataPath` — the machine's own `/data` qcow2
- `varsPath` — the machine's own UEFI variable store
- `supportDirectory` — where this machine's snapshot stamps and RAM scratch file go
- `ramMiB`, `cpuCount`, `width`, `height`, `dpi` (`rootEnabled` is kept in the
  record but has no UI or QEMU wiring yet)
- `legacyGuest` — true only for the guest adopted from a pre-machine-manager install
- `createdAt`, `lastBootedAt`

The list is written to `Documents/husk-machines.json`. Machines live under
`Documents/Machines/<UUID>/`:

```
userdata.qcow2        the machine's Android data
efi-vars.fd           its UEFI variables
husk-snapshot.mib     RAM size the snapshot was taken at
husk-snapshot.display display device the snapshot was taken with
husk-memory-strategy  memory backend the snapshot was taken with
guest-ram.bin         file-backed guest RAM scratch space
husk-ram-*            memory-size attempt/proven/failed markers
```

Imported images are shared by release, not per machine, because the system disk
is read-only from Android's point of view and costs a gigabyte per copy:

```
Documents/AndroidImages/<releaseID>/system.qcow2
Documents/AndroidImages/<releaseID>/system.img
```

A `.img` is opened with `format=raw`; anything else is opened as `qcow2`. The
machine derives the format from the path extension.

## Booting

`ContentView.start(_:)` is the only entry point. It checks that the machine has a
system image, claims JIT, sets `QemuRunner.activeMachine`, marks the machine as
last booted, and starts QEMU on its dedicated thread.

`QemuRunner` reads the active machine for:

- `vda` system disk and its format
- `vdb` userdata disk, named `huskvmstate` so QEMU snapshots state there
- the `pflash` UEFI variable store
- RAM size, vCPU count, and the screen geometry used by the display
- the support directory for snapshot stamps and the RAM scratch file

QEMU accepts one machine per process, and iOS cannot spawn processes, so the app
supports exactly one running machine. The list marks the rest as busy while it
runs; Start on another machine opens the running one.

## Saved state

After Android settles, `QemuRunner` saves a snapshot into that machine's
`userdata.qcow2`. The snapshot is valid only for the machine shape that produced
it, so the stamps record RAM, display mode and memory strategy. A stamp mismatch
retires the snapshot and cold-boots rather than restoring into the wrong shape.

The shipped Android 13 install keeps a special pre-booted snapshot. An install
that had that guest before the machine manager existed is adopted once as a
`legacyGuest`, using the global `Documents/lineage-*` paths and the shipped
snapshot. It can be reset but not deleted. A machine created from the built-in
image gets its own blank userdata and cold-boots once, because sharing the
shipped `/data` between machines would also share every app and account.

## Importing an image

`VMManager.importImage(_:for:)` validates the file, copies it into the release's
image slot, and replaces any previous image for that release. It is deliberately
narrow:

- `.qcow2` is checked with `GuestImage.validate` (header and format).
- `.img` is accepted as a raw disk when it is at least 64 MiB.
- The machine always gets its own userdata and UEFI variables. An imported image
  cannot bring a stale boot entry or somebody else's `/data` with it.

It does **not** convert a phone image, a partition dump, a sparse Android image,
or an image built for a different machine type. The disk has to be bootable under
QEMU's `virt` machine with the same virtio devices Husk uses. Those are real
constraints, not validation Husk can perform cheaply, and a disk that fails them
will drop to the UEFI shell or fail inside the Android kernel.

## Adding a version

1. Add an `AndroidRelease` row with an id, version, API, defaults and `builtIn:
   false`.
2. Make sure its default screen and minimum RAM fit the release.
3. Import a compatible system disk for that release.
4. Create a machine and boot it. The per-machine paths, snapshot stamps and
   hardware settings are already generic, so no QEMU change is needed unless the
   image expects a different device.

## What is intentionally absent

- PS4 packaging and game folders are not part of the machine manager.
- There is no hosted download for Android 4.4–12 or 14. The UI says "Image
  needed" and opens the importer rather than pretending a download exists.
- There is no simultaneous multi-boot. The process owns one QEMU instance.
- There is no image conversion or partition extraction on device.
