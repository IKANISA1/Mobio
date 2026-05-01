package rw.mobi.app.ledger.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * Cached MoMo provider metadata from Supabase.
 * Used for offline sender ID filtering — no network call needed in BroadcastReceiver.
 * Refreshed every 24 hours when online.
 */
@Entity(
    tableName = "providers_cache",
    indices = [
        Index(value = ["sender_id"]),
        Index(value = ["dialing_code"])
    ]
)
data class ProviderEntity(
    @PrimaryKey
    val id: String, // AO, RW, etc.

    @ColumnInfo(name = "name")
    val name: String,

    @ColumnInfo(name = "flag")
    val flag: String,

    @ColumnInfo(name = "dialing_code")
    val dialingCode: String,

    @ColumnInfo(name = "currency")
    val currency: String,

    @ColumnInfo(name = "phone_placeholder")
    val phonePlaceholder: String,

    @ColumnInfo(name = "telecom_provider")
    val telecomProvider: String?,

    @ColumnInfo(name = "momo_brand")
    val momoBrand: String?,

    @ColumnInfo(name = "ussd_code_format")
    val ussdCodeFormat: String?,

    @ColumnInfo(name = "ussd_number_format")
    val ussdNumberFormat: String?,

    @ColumnInfo(name = "currency_name")
    val currencyName: String?,

    @ColumnInfo(name = "sender_id")
    val senderId: String?,

    @ColumnInfo(name = "active")
    val active: Boolean = true,

    @ColumnInfo(name = "sort_order")
    val sortOrder: Int = 99,

    @ColumnInfo(name = "cached_at")
    val cachedAt: Long = System.currentTimeMillis()
)
