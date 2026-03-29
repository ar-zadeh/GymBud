package com.example.hackathon.ui.theme

import android.os.Build
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.dynamicDarkColorScheme
import androidx.compose.material3.dynamicLightColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext

private val DarkColorScheme = darkColorScheme(
    primary = Flame300,
    onPrimary = Iron900,
    primaryContainer = Color(0xFF4A2415),
    onPrimaryContainer = Color(0xFFFFDACC),
    secondary = Mint300,
    onSecondary = Iron900,
    secondaryContainer = Color(0xFF114C45),
    onSecondaryContainer = Color(0xFFB7F4EC),
    tertiary = Sand200,
    onTertiary = Iron900,
    background = Color(0xFF0F131A),
    onBackground = Color(0xFFE8EDF6),
    surface = Color(0xFF131924),
    onSurface = Color(0xFFE8EDF6),
    surfaceVariant = Color(0xFF253041),
    onSurfaceVariant = Color(0xFFCED7E5),
    outline = Color(0xFF7A869A)
)

private val LightColorScheme = lightColorScheme(
    primary = Flame500,
    onPrimary = Color.White,
    primaryContainer = Color(0xFFFFE2D4),
    onPrimaryContainer = Color(0xFF3A170A),
    secondary = Mint500,
    onSecondary = Color.White,
    secondaryContainer = Color(0xFFC9F5EE),
    onSecondaryContainer = Color(0xFF003731),
    tertiary = Color(0xFF725B45),
    onTertiary = Color.White,
    background = Iron050,
    onBackground = Iron900,
    surface = Color.White,
    onSurface = Iron900,
    surfaceVariant = Color(0xFFEEF2F8),
    onSurfaceVariant = Iron700,
    outline = Color(0xFF8A93A5)
)

@Composable
fun HackathonTheme(
    darkTheme: Boolean = true,
    // Dynamic color is available on Android 12+
    dynamicColor: Boolean = false,
    content: @Composable () -> Unit
) {
    val colorScheme = when {
        dynamicColor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
            val context = LocalContext.current
            if (darkTheme) dynamicDarkColorScheme(context) else dynamicLightColorScheme(context)
        }

        darkTheme -> DarkColorScheme
        else -> LightColorScheme
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = Typography,
        content = content
    )
}