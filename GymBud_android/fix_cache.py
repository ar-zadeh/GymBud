import re

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'r', encoding='utf-8') as f:
    text = f.read()

target = r'''    private val exerciseService: ExerciseDbService by lazy \{
        val host = BuildConfig\.EXERCISE_DB_API_HOST\.ifBlank \{
            "edb-with-videos-and-images-by-ascendapi\.p\.rapidapi\.com"
        \}
        val apiKey = BuildConfig\.EXERCISE_DB_API_KEY

        val logger = HttpLoggingInterceptor\(\)\.apply \{
            level = HttpLoggingInterceptor\.Level\.BASIC
        \}

        val cacheSize = \(10 \* 1024 \* 1024\)\.toLong\(\)
        val cache = okhttp3\.Cache\(getApplication<android\.app\.Application>\(\)\.cacheDir, cacheSize\)

        val cacheInterceptor = okhttp3\.Interceptor \{ chain ->
            val request = chain\.request\(\)
            val response = chain\.proceed\(request\)
            if \(response\.isSuccessful\) \{
                response\.newBuilder\(\)
                    \.removeHeader\("Pragma"\)
                    \.removeHeader\("Cache-Control"\)
                    \.header\("Cache-Control", "public, max-age=604800"\)
                    \.build\(\)
            \} else \{
                response
            \}
        \}

        val client = OkHttpClient\.Builder\(\)
            \.cache\(cache\)
            \.addNetworkInterceptor\(cacheInterceptor\)
            \.addInterceptor \{ chain ->
                val builder = chain\.request\(\)\.newBuilder\(\)
                    \.header\("Content-Type", "application/json"\)
                    \.header\("x-rapidapi-host", host\)
                if \(apiKey\.isNotBlank\(\)\) \{
                    builder\.header\("x-rapidapi-key", apiKey\)
                \}
                chain\.proceed\(builder\.build\(\)\)
            \}
            \.addInterceptor\(logger\)
            \.build\(\)

        Retrofit\.Builder\(\)
            \.baseUrl\("https://\$host/"\)
            \.client\(client\)
            \.addConverterFactory\(GsonConverterFactory\.create\(\)\)
            \.build\(\)
            \.create\(ExerciseDbService::class\.java\)
    \}

    private val pixabayService: PixabayService by lazy \{
        Retrofit\.Builder\(\)
            \.baseUrl\("https://pixabay\.com/"\)
            \.addConverterFactory\(GsonConverterFactory\.create\(\)\)
            \.build\(\)
            \.create\(PixabayService::class\.java\)
    \}'''

new_text = r'''    private val baseCachedClient: OkHttpClient by lazy {
        val logger = HttpLoggingInterceptor().apply {
            level = HttpLoggingInterceptor.Level.BASIC
        }
        val cacheSize = (50 * 1024 * 1024).toLong() // 50MB cache for images and json
        val cache = okhttp3.Cache(getApplication<android.app.Application>().cacheDir, cacheSize)

        val cacheInterceptor = okhttp3.Interceptor { chain ->
            val request = chain.request()
            // Force cache usage if network is not providing it
            val response = chain.proceed(request)
            if (response.isSuccessful) {
                response.newBuilder()
                    .removeHeader("Pragma")
                    .removeHeader("Cache-Control")
                    .header("Cache-Control", "public, max-age=6048000") // heavily cache for 70 days
                    .build()
            } else {
                response
            }
        }

        OkHttpClient.Builder()
            .cache(cache)
            .addNetworkInterceptor(cacheInterceptor)
            // Add an interceptor to force read from cache if offline or to skip network if cached
            .addInterceptor { chain ->
                var request = chain.request()
                // Force cache for GET requests
                if (request.method == "GET") {
                    request = request.newBuilder()
                        .header("Cache-Control", "public, max-age=6048000")
                        .build()
                }
                chain.proceed(request)
            }
            .addInterceptor(logger)
            .build()
    }

    private val exerciseService: ExerciseDbService by lazy {
        val host = BuildConfig.EXERCISE_DB_API_HOST.ifBlank {
            "edb-with-videos-and-images-by-ascendapi.p.rapidapi.com"
        }
        val apiKey = BuildConfig.EXERCISE_DB_API_KEY
        
        val client = baseCachedClient.newBuilder()
            .addInterceptor { chain ->
                val builder = chain.request().newBuilder()
                    .header("Content-Type", "application/json")
                    .header("x-rapidapi-host", host)
                if (apiKey.isNotBlank()) {
                    builder.header("x-rapidapi-key", apiKey)
                }
                chain.proceed(builder.build())
            }
            .build()

        Retrofit.Builder()
            .baseUrl("https://$host/")
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ExerciseDbService::class.java)
    }

    private val pixabayService: PixabayService by lazy {
        Retrofit.Builder()
            .baseUrl("https://pixabay.com/")
            .client(baseCachedClient)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(PixabayService::class.java)
    }'''

text = re.sub(target, new_text, text, count=1)

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'w', encoding='utf-8') as f:
    f.write(text)
