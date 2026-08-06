package mtk.flowscope.ui.timer

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.theme.ThemeConfiguration

private val SuggestedCategories = listOf(
    "Work", "Study", "Exercise", "Creative", "Chores",
    "Reading", "Coding", "Meeting", "Gaming", "General",
)

/** Ported from `SessionSetupView.swift`. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionSetupSheet(
    config: ThemeConfiguration,
    onDismiss: () -> Unit,
    onStart: (name: String, category: String) -> Unit,
) {
    var sessionName by remember { mutableStateOf("") }
    var category by remember { mutableStateOf("") }
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    val trimmedName = sessionName.trim()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = config.backgroundBottom,
        contentColor = config.textPrimary,
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp)
                .padding(bottom = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                Icons.Filled.Timer,
                contentDescription = null,
                tint = config.primary,
                modifier = Modifier.size(56.dp),
            )
            Spacer(Modifier.height(16.dp))
            Text(
                "What are you working on?",
                color = config.textPrimary,
                fontSize = 19.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
            Spacer(Modifier.height(24.dp))

            FieldLabel("Session Name", config)
            Spacer(Modifier.height(8.dp))
            ThemedTextField(
                value = sessionName,
                onValueChange = { sessionName = it },
                placeholder = "e.g., Writing blog post",
                config = config,
            )

            Spacer(Modifier.height(20.dp))

            FieldLabel("Category", config)
            Spacer(Modifier.height(8.dp))
            ThemedTextField(
                value = category,
                onValueChange = { category = it },
                placeholder = "e.g., Work, Study, or your own…",
                config = config,
            )
            Spacer(Modifier.height(10.dp))

            // Chips are shortcuts — the field itself stays free text.
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                SuggestedCategories.forEach { suggestion ->
                    CategoryChip(
                        title = suggestion,
                        isSelected = category == suggestion,
                        config = config,
                    ) { category = suggestion }
                }
                Spacer(Modifier.width(6.dp))
            }

            Spacer(Modifier.height(28.dp))

            StartButton(
                config = config,
                enabled = trimmedName.isNotEmpty(),
                onClick = {
                    val trimmedCategory = category.trim()
                    onStart(
                        trimmedName,
                        if (trimmedCategory.isEmpty()) "General" else trimmedCategory,
                    )
                },
            )
        }
    }
}

@Composable
private fun FieldLabel(text: String, config: ThemeConfiguration) {
    Text(
        text,
        color = config.textSecondary,
        fontSize = 14.sp,
        fontWeight = FontWeight.SemiBold,
        fontFamily = config.fontDesign.fontFamily,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
fun ThemedTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    config: ThemeConfiguration,
    modifier: Modifier = Modifier,
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(config.cornerRadius))
            .background(config.surface)
            .border(
                1.dp,
                config.primary.copy(alpha = 0.35f),
                RoundedCornerShape(config.cornerRadius),
            )
            .padding(horizontal = 14.dp, vertical = 12.dp),
    ) {
        if (value.isEmpty()) {
            Text(
                placeholder,
                color = config.textSecondary.copy(alpha = 0.7f),
                fontSize = 15.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        BasicTextField(
            value = value,
            onValueChange = onValueChange,
            singleLine = true,
            textStyle = TextStyle(
                color = config.textPrimary,
                fontSize = 15.sp,
                fontFamily = config.fontDesign.fontFamily,
            ),
            cursorBrush = SolidColor(config.primary),
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

@Composable
fun CategoryChip(
    title: String,
    isSelected: Boolean,
    config: ThemeConfiguration,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .then(
                if (isSelected) {
                    Modifier.background(Brush.horizontalGradient(config.accentColors))
                } else {
                    Modifier
                        .background(config.surface)
                        .border(1.dp, config.primary.copy(alpha = 0.25f), CircleShape)
                },
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        Text(
            title,
            color = if (isSelected) Color.Black else config.textPrimary,
            fontSize = 14.sp,
            fontFamily = config.fontDesign.fontFamily,
        )
    }
}

@Composable
private fun StartButton(
    config: ThemeConfiguration,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            // Dimmed until a session name is entered, matching the iOS sheet.
            .alpha(if (enabled) 1f else 0.45f)
            .clip(RoundedCornerShape(config.cornerRadius))
            .background(Brush.horizontalGradient(config.accentColors))
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(vertical = 16.dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(Icons.Filled.PlayCircle, null, tint = Color.Black)
            Spacer(Modifier.width(8.dp))
            Text(
                "Start Session",
                color = Color.Black,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
    }
}
