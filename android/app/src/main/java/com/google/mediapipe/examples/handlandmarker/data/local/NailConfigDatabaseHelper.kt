package com.google.mediapipe.examples.handlandmarker.data.local

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import com.google.gson.Gson
import com.google.mediapipe.examples.handlandmarker.model.NailSetConfig

class NailConfigDatabaseHelper(
    context: Context,
    private val gson: Gson = Gson()
) : SQLiteOpenHelper(context, DATABASE_NAME, null, DATABASE_VERSION) {

    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE $TABLE_CONFIGS (
                $COLUMN_NAIL_SET_ID INTEGER PRIMARY KEY,
                $COLUMN_CONFIG_JSON TEXT NOT NULL,
                $COLUMN_UPDATED_AT INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        db.execSQL("DROP TABLE IF EXISTS $TABLE_CONFIGS")
        onCreate(db)
    }

    fun loadConfig(nailSetId: Int): NailSetConfig? {
        return readableDatabase.query(
            TABLE_CONFIGS,
            arrayOf(COLUMN_CONFIG_JSON),
            "$COLUMN_NAIL_SET_ID = ?",
            arrayOf(nailSetId.toString()),
            null,
            null,
            null
        ).use { cursor ->
            if (!cursor.moveToFirst()) {
                null
            } else {
                gson.fromJson(cursor.getString(0), NailSetConfig::class.java)
            }
        }
    }

    fun saveConfig(nailSetId: Int, config: NailSetConfig) {
        val values = ContentValues().apply {
            put(COLUMN_NAIL_SET_ID, nailSetId)
            put(COLUMN_CONFIG_JSON, gson.toJson(config))
            put(COLUMN_UPDATED_AT, System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict(
            TABLE_CONFIGS,
            null,
            values,
            SQLiteDatabase.CONFLICT_REPLACE
        )
    }

    private companion object {
        const val DATABASE_NAME = "nail_configs.db"
        const val DATABASE_VERSION = 1
        const val TABLE_CONFIGS = "nail_set_configs"
        const val COLUMN_NAIL_SET_ID = "nail_set_id"
        const val COLUMN_CONFIG_JSON = "config_json"
        const val COLUMN_UPDATED_AT = "updated_at"
    }
}
