import re

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'r', encoding='utf-8') as f:
    text = f.read()

target = r'''        val cacheInterceptor = okhttp3\.Interceptor \{ chain ->
            val request = chain\.request\(\)
            val response = chain\.proceed\(request\)
            response\.newBuilder\(\)
                \.removeHeader\("Pragma"\)
                \.removeHeader\("Cache-Control"\)
                \.header\("Cache-Control", "public, max-age=604800"\)
                \.build\(\)
        \}'''

new_text = r'''        val cacheInterceptor = okhttp3.Interceptor { chain ->
            val request = chain.request()
            val response = chain.proceed(request)
            if (response.isSuccessful) {
                response.newBuilder()
                    .removeHeader("Pragma")
                    .removeHeader("Cache-Control")
                    .header("Cache-Control", "public, max-age=604800")
                    .build()
            } else {
                response
            }
        }'''

text = re.sub(target, new_text, text, count=1)

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'w', encoding='utf-8') as f:
    f.write(text)
