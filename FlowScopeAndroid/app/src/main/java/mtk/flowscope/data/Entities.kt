package mtk.flowscope.data

import androidx.room.Embedded
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation
import java.util.UUID

/**
 * Room equivalents of the SwiftData `@Model` types in Session.swift.
 *
 * SwiftData's implicit relationship becomes an explicit foreign key with a
 * cascading delete, matching `@Relationship(deleteRule: .cascade)`.
 */

@Entity(tableName = "sessions")
data class SessionEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    /** Epoch millis. */
    val startTime: Long,
    /** Epoch millis; null while the session is still open. */
    val endTime: Long? = null,
    /** Seconds. */
    val totalDuration: Double = 0.0,
    val name: String = "Untitled Session",
    val category: String = "General",
)

@Entity(
    tableName = "mood_logs",
    foreignKeys = [
        ForeignKey(
            entity = SessionEntity::class,
            parentColumns = ["id"],
            childColumns = ["sessionId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("sessionId")],
)
data class MoodLogEntity(
    @PrimaryKey val id: String = UUID.randomUUID().toString(),
    val sessionId: String,
    /** Seconds since the session started. */
    val timestamp: Double,
    val satisfaction: Int,
    val note: String = "",
)

/** A session with its mood logs — the shape every screen actually consumes. */
data class SessionWithMoodLogs(
    @Embedded val session: SessionEntity,
    @Relation(parentColumn = "id", entityColumn = "sessionId")
    val moodLogs: List<MoodLogEntity>,
) {
    val id: String get() = session.id
    val name: String get() = session.name
    val category: String get() = session.category
    val startTime: Long get() = session.startTime

    val durationInMinutes: Int get() = (session.totalDuration / 60).toInt()

    val averageMood: Int
        get() = if (moodLogs.isEmpty()) 0 else moodLogs.sumOf { it.satisfaction } / moodLogs.size
}
