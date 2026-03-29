package com.example.hackathon

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import coil.Coil
import coil.ImageLoader
import coil.disk.DiskCache
import coil.memory.MemoryCache
import coil.request.CachePolicy
import com.example.hackathon.ui.theme.HackathonTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Initialize an aggressive, unified application-wide Image Loader
        val imageLoader = ImageLoader.Builder(this)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .memoryCache {
                MemoryCache.Builder(this)
                    .maxSizePercent(0.25)
                    .build()
            }
            .diskCachePolicy(CachePolicy.ENABLED)
            .diskCache {
                DiskCache.Builder()
                    .directory(cacheDir.resolve("image_cache"))
                    .maxSizePercent(0.10) // generous 10% of free space
                    .build()
            }
            // THIS is the magic line. Some image servers (like AWS/Cloudflare) send "cache-control: no-cache" limits.
            // This forces Coil to ignore them and always load out of disk cache without doing a remote conditional GET!
            .respectCacheHeaders(false)
            .build()
            
        Coil.setImageLoader(imageLoader)

        enableEdgeToEdge()
        setContent {
            HackathonTheme {
                GymApp()
            }
        }
    }
}
