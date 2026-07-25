package com.nurio.studyleader.android.auth

class SocialAuthCoordinator(
    private val startKakao: () -> Unit,
    private val openSystemAuth: (String) -> Unit
) {
    fun start(route: SocialAuthRoute) {
        when (route.provider) {
            SocialAuthProvider.KAKAO -> startKakao()
            SocialAuthProvider.GOOGLE,
            SocialAuthProvider.NAVER,
            SocialAuthProvider.APPLE -> openSystemAuth(route.url)
        }
    }
}
