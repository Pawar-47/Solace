# Java memory on Linux Mint XFCE, 8 GB RAM

Short answer: raise the heap from 2 GB to **3 GB**, set the minimum equal to the
maximum, and spend the rest of your attention on resolution and render distance
instead. More heap will not raise your frame rate — with a shader pack you are almost
always GPU-bound — but it removes the stutter that comes from garbage collection and
from chunk loading, which is the thing that actually feels bad on 8 GB.

This page is written for the target machine: Intel Core i3-5005U, Intel HD 5500
(integrated, so it has no memory of its own), 8 GB RAM, Linux Mint XFCE.

## What the heap does and does not do

- **Does:** holds the game's world data, chunk meshes, textures staged for upload, and
  the pack's colour tables. Too small a heap means the collector runs constantly and
  the game hitches every few seconds while it walks around.
- **Does not:** make the shader faster. Every pixel is shaded on the HD 5500. Going
  from 2 GB to 3 GB changes hitching, not frames per second.
- **Costs:** every byte the JVM takes is a byte XFCE, the browser and — on an
  integrated GPU — the frame buffer cannot have. That is why the ceiling here is 3 GB,
  not "all of it".

## The numbers for 8 GB

| Heap | Verdict |
| --- | --- |
| 2 GB | Works, but the collector runs often once you move between chunks. This is the floor. |
| **3 GB** | **The recommendation.** Leaves ~1 GB for XFCE, ~1 GB for the iGPU's frame buffers, and headroom for a browser tab. |
| 3.5 GB | Fine if you close the browser. Little margin once the GPU memory is counted. |
| 4 GB+ | Do not. With 8 GB total and integrated graphics this pushes the system into swap, and swapping makes the game worse than a small heap ever did. |

Set the minimum equal to the maximum (`-Xms3G -Xmx3G`). A heap that has to grow
reallocates and re-touches memory mid-game, which is a stutter you can hear.

## The arguments to paste

Open your launcher's JVM arguments and replace what is there with this:

```
-Xms3G -Xmx3G -XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200
-XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:G1NewSizePercent=30
-XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20
-XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4
-XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90
-XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32
-XX:MaxTenuringThreshold=1 -XX:+PerfDisableSharedMem
```

These are the long-standing "Aikar" G1 settings, which are tuned for Minecraft's
allocation pattern; they are what most modded players on small heaps run.

If you keep a browser open while playing, drop every `3G` to `2G` — an out-of-memory
kill loses the world you were in, and `dmesg` will show the OOM killer taking `java`
rather than a crash inside the game.

**Where to put them:**

- **Official launcher:** Installations → your instance → ⋯ → Edit → More options →
  JVM arguments.
- **Prism / MultiMC:** Settings → Java → JVM arguments (applies to every instance) or
  the instance's Settings → Java → Override memory / JVM arguments.
- **ATLauncher / GDLauncher:** instance settings → Java/Memory.

## Swap, because 8 GB is 8 GB

A swap file turns "the game was killed" into "the next ten seconds are slow". XFCE
with a 4 GB swapfile and a low swappiness is a good trade:

```bash
sudo fallocate -l 4G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
```

Then keep the kernel from being eager about it:

```bash
echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf
echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.d/99-swappiness.conf
sudo sysctl --system
```

On a machine with an SSD, zram is a better first layer than a swap file because it
compresses instead of writing: `sudo apt install zram-tools`, then set
`PERCENT=25` and `ALGO=zstd` in `/etc/default/zramswap`. Use one or the other, not
both, unless you know why you want both.

## The GPU memory you cannot allocate with Java

The HD 5500 has no VRAM. It carves its frame buffers out of the same 8 GB, and how
much it takes is a firmware setting:

- Check what it took: `sudo dmesg | grep -i "Memory:"` or look at `free -h` after
  boot — the difference between the installed 8 GB and what the kernel reports is
  usually the iGPU's reserved aperture.
- Some laptops let you raise the DVMT pre-allocated size in the BIOS to 512 MB. If
  yours is locked, nothing in Linux can change it, and 512 MB is enough for this pack
  at 1600x900.
- Check the driver is the right one: `glxinfo | grep "OpenGL renderer"` should say
  `Mesa Intel(R) HD Graphics 5500 (BDW GT2)`. If it says `llvmpipe`, you are on the
  CPU rasteriser and no amount of heap will help.

## Things that help more than heap

1. **Resolution.** 1600x900, or 1366x768. The pack is fill-rate bound; this is the
   single biggest lever on an HD 5500.
2. **Render distance 6, simulation distance 4.** Chunk building is CPU work on two
   cores.
3. **XFCE's compositor off while playing:** Settings → Window Manager Tweaks →
   Compositor → uncheck "Enable display compositing". It saves the iGPU a full-screen
   blit per frame.
4. **`mesa_glthread=true`** in the launch environment — the Mesa threaded GL dispatch
   helps on two cores.
5. **VSync off, max framerate unlimited** in the game's video settings, and let the
   pack's own frame cost decide.
6. **Start on the `LowEnd` profile**, then walk up to `Default`. `Beauty` and
   `PerformancePlus` are for machines with headroom.

## How to tell whether it worked

- `free -h` while playing: if swap used is climbing steadily, the heap is too big for
  what else you are running — drop it by 500 MB.
- Watch the stutter pattern. Regular hitches every few seconds that stop once you
  stand still = heap/GC; hitches that scale with how much is on screen = GPU, and no
  JVM flag will fix it.
- `intel_gpu_top` (package `intel-gpu-tools`) shows the GPU sitting at 100% while
  the CPU idles — that is the GPU-bound case, and it means you are already at the
  right settings for the shader.
