package rw.mobi.app.ledger.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory

/**
 * Room database with SQLCipher encryption.
 * Contains SMS offline queue and cached MoMo providers.
 */
@Database(
    entities = [SmsQueueEntity::class, ProviderEntity::class],
    version = 2,
    exportSchema = false
)
abstract class PayLedgerDatabase : RoomDatabase() {

    abstract fun smsQueueDao(): SmsQueueDao
    abstract fun providerDao(): ProviderDao

    companion object {
        private const val DATABASE_NAME = "payledger_encrypted.db"

        /**
         * Migration from v1 (momo_providers flat cache) to v2 (countries with rich metadata).
         * Recreates providers_cache with new columns. SMS queue is preserved.
         */
        private val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // Drop old providers cache (reference data only — not user data)
                db.execSQL("DROP TABLE IF EXISTS providers_cache")
                // Recreate with new schema (ProviderEntity v2)
                db.execSQL(
                    """
                    CREATE TABLE IF NOT EXISTS providers_cache (
                        id TEXT NOT NULL PRIMARY KEY,
                        name TEXT NOT NULL,
                        flag TEXT NOT NULL,
                        dialing_code TEXT NOT NULL,
                        currency TEXT NOT NULL,
                        phone_placeholder TEXT NOT NULL,
                        telecom_provider TEXT,
                        momo_brand TEXT,
                        sender_id TEXT,
                        active INTEGER NOT NULL DEFAULT 1,
                        sort_order INTEGER NOT NULL DEFAULT 99,
                        cached_at INTEGER NOT NULL DEFAULT 0
                    )
                    """.trimIndent()
                )
                db.execSQL("CREATE INDEX IF NOT EXISTS index_providers_cache_sender_id ON providers_cache (sender_id)")
                db.execSQL("CREATE INDEX IF NOT EXISTS index_providers_cache_dialing_code ON providers_cache (dialing_code)")
            }
        }

        @Volatile
        private var INSTANCE: PayLedgerDatabase? = null

        fun getInstance(context: Context): PayLedgerDatabase {
            return INSTANCE ?: synchronized(this) {
                INSTANCE ?: buildDatabase(context).also { INSTANCE = it }
            }
        }

        private fun buildDatabase(context: Context): PayLedgerDatabase {
            // Load SQLCipher native library
            System.loadLibrary("sqlcipher")

            // Get or generate encryption key from Android Keystore
            val passphrase = getOrCreateDatabaseKey(context)
            val factory = SupportOpenHelperFactory(passphrase)

            return Room.databaseBuilder(
                context.applicationContext,
                PayLedgerDatabase::class.java,
                DATABASE_NAME
            )
                .openHelperFactory(factory)
                .addMigrations(MIGRATION_1_2)
                .build()
        }

        /**
         * Get or create a secure database encryption key.
         * Uses EncryptedSharedPreferences backed by Android Keystore.
         */
        private fun getOrCreateDatabaseKey(context: Context): ByteArray {
            val prefs = rw.mobi.app.ledger.util.PrefsManager.getEncryptedPrefs(context)
            val keyString = prefs.getString("db_encryption_key", null)

            return if (keyString != null) {
                keyString.toByteArray(Charsets.UTF_8)
            } else {
                // Generate a random 32-byte key
                val key = java.security.SecureRandom().let { random ->
                    ByteArray(32).also { random.nextBytes(it) }
                }
                val encoded = android.util.Base64.encodeToString(key, android.util.Base64.NO_WRAP)
                prefs.edit().putString("db_encryption_key", encoded).apply()
                encoded.toByteArray(Charsets.UTF_8)
            }
        }
    }
}
