plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "com.example.hackathon"
    compileSdk {
        version = release(36) {
            minorApiLevel = 1
        }
    }

    defaultConfig {
        applicationId = "com.example.hackathon"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"

        val exerciseDbApiKey = providers.gradleProperty("EXERCISE_DB_API_KEY").orElse("").get()
        val exerciseDbApiHost = providers.gradleProperty("EXERCISE_DB_HOST").orElse("exercisedb.p.rapidapi.com").get()
        val geminiApiKey = providers.gradleProperty("GEMINI_API_KEY").orElse("").get()
        val pixabayApiKey = providers.gradleProperty("PIXABAY_API_KEY").orElse("").get()
        buildConfigField("String", "EXERCISE_DB_API_KEY", "\"$exerciseDbApiKey\"")
        buildConfigField("String", "EXERCISE_DB_API_HOST", "\"$exerciseDbApiHost\"")
        buildConfigField("String", "GEMINI_API_KEY", "\"$geminiApiKey\"")
        buildConfigField("String", "PIXABAY_API_KEY", "\"$pixabayApiKey\"")

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.datastore.preferences)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.material.icons.extended)
    implementation(libs.retrofit)
    implementation(libs.retrofit.converter.gson)
    implementation(libs.okhttp.logging)
    implementation(libs.coil.compose)
    implementation("com.google.mlkit:pose-detection:17.0.0")
    implementation("com.google.mlkit:pose-detection-accurate:17.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    implementation("com.google.android.gms:play-services-wearable:18.2.0")
    testImplementation(libs.junit)
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.espresso.core)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
android {
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

dependencies {
    val cameraxVersion = "1.3.1"
    implementation("androidx.camera:camera-core:$cameraxVersion")
    implementation("androidx.camera:camera-camera2:$cameraxVersion")
    implementation("androidx.camera:camera-lifecycle:$cameraxVersion")
    implementation("androidx.camera:camera-view:$cameraxVersion")
    implementation("com.google.guava:guava:32.1.3-android") 
}



dependencies {





}


dependencies {
    implementation("org.nanohttpd:nanohttpd:2.3.1")
}
