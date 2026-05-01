package rw.mobi.app.ledger.data.local

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

/**
 * SMS offline queue entity.
 * Stores raw MoMo SMS before sync to Supabase.
 * SHA-256 hash prevents duplicate uploads.
 */
@Entity(
    tableName = "sms_queue",
    indices = [
        Index(value = ["sms_hash", "agent_id"], unique = true),
        Index(value = ["status"])
    ]
)
data class SmsQueueEntity(
    @PrimaryKey(autoGenerate = true)
    val id: Long = 0,

    @ColumnInfo(name = "sms_hash")
    val smsHash: String,

    @ColumnInfo(name = "agent_id")
    val agentId: String,

    @ColumnInfo(name = "raw_sms")
    val rawSms: String,

    @ColumnInfo(name = "sender")
    val sender: String,

    @ColumnInfo(name = "received_at")
    val receivedAt: Long,

    @ColumnInfo(name = "status")
    val status: String = SmsStatus.PENDING.name,

    @ColumnInfo(name = "retries")
    val retries: Int = 0,

    @ColumnInfo(name = "last_error")
    val lastError: String? = null
)

enum class SmsStatus {
    PENDING,
    UPLOADING,
    SYNCED,
    FAILED
}
