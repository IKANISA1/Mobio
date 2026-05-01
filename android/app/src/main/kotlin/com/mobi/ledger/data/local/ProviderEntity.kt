package com.mobi.ledger.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.PrimaryKey

/**
 * Cached MoMo provider configuration.
 * Maps country code and sender IDs for fast local SMS filtering.
 */
@Entity(tableName = "providers_cache")
data class ProviderEntity(
    @PrimaryKey
    @ColumnInfo(name = "country_code")
    val countryCode: String,

    @ColumnInfo(name = "sender_id")
    val senderId: String,

    @ColumnInfo(name = "ussd_code_format")
    val ussdCodeFormat: String? = null,

    @ColumnInfo(name = "is_active")
    val isActive: Boolean = true,

    @ColumnInfo(name = "updated_at")
    val updatedAt: Long = System.currentTimeMillis()
)
