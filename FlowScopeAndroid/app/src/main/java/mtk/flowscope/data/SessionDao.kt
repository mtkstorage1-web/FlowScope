package mtk.flowscope.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.RoomDatabase
import androidx.room.Transaction
import kotlinx.coroutines.flow.Flow

@Dao
interface SessionDao {

    @Transaction
    @Query("SELECT * FROM sessions ORDER BY startTime DESC")
    fun observeAll(): Flow<List<SessionWithMoodLogs>>

    @Transaction
    @Query("SELECT * FROM sessions ORDER BY startTime DESC")
    suspend fun getAll(): List<SessionWithMoodLogs>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertSession(session: SessionEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertMoodLogs(logs: List<MoodLogEntity>)

    @Transaction
    suspend fun saveSession(session: SessionEntity, logs: List<MoodLogEntity>) {
        insertSession(session)
        insertMoodLogs(logs)
    }

    @Query("DELETE FROM sessions WHERE id = :sessionId")
    suspend fun deleteSession(sessionId: String)
}

@Database(
    entities = [SessionEntity::class, MoodLogEntity::class],
    version = 1,
    exportSchema = true,
)
abstract class FlowScopeDatabase : RoomDatabase() {
    abstract fun sessionDao(): SessionDao
}
