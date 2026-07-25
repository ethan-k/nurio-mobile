package com.nurio.studyleader.android.fragments

import dev.hotwire.navigation.destinations.HotwireDestinationDeepLink
import dev.hotwire.navigation.fragments.HotwireWebBottomSheetFragment

@HotwireDestinationDeepLink(uri = "hotwire://fragment/web/modal")
class WebModalFragment : HotwireWebBottomSheetFragment()
