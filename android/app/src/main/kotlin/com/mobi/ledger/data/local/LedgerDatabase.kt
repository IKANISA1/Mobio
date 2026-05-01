package com.mobi.ledger.data.local

import android.content.Context
import androidx.room.Database
import androidx.room.Room
import androidx.room.RoomDatabase
import net.zetetic.database.sqlcipher.SupportOpenHelperFactory

@Database(
    entities = [SmsQueueEntity::class, ProviderEntity::class],
    version = 1,
    exportSchema = false
)
abstract class LedgerDatabase : RoomDatabase() {

    abstract fun smsQueueDao(): SmsQueueDao
    abstract fun providerDao(): ProviderDao

    companion object {
        @Volatile
        private var INSTANCE: LedgerDatabase? = null

        fun getInstance(context: Context): LedgerDatabase {
            return INSTANCE ?: synchronized(this) {
                val instance = Room.databaseBuilder(
                    context.applicationContext,
                    LedgerDatabase::class.java,
                    "mobi_ledger.db"
                )
                // H3: Secure local DB with SQLCipher
                // Passphrase is fixed for now, but in Phase 4 we should derive it
                // from a device-specific key or user's member_id hash.
                .openHelperFactory(SupportOpenHelperFactory("mobi_secure_passphrase".toByteArray()))
                .fallbackToDestructiveMigration()
                .build()
                INSTANCE = instance
                instance
            }
        }
    }
}
