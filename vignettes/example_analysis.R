#!/usr/bin/env Rscript
# Example script demonstrating birdweather package usage

library(birdweather)
library(dplyr)
library(ggplot2)

# ============================================================================
# SETUP
# ============================================================================

# Set your API token (get this from birdweather.com)
# For first time: bw_set_token("your_token", install = TRUE)
# After that, it will be loaded automatically

# Check if token is available
if (!bw_has_token()) {
  stop("Please set your BirdWeather API token with bw_set_token()")
}

# ============================================================================
# EXPLORE YOUR STATIONS
# ============================================================================

# Get your stations
my_stations <- bw_get_my_stations()
print("Your BirdWeather stations:")
print(my_stations)

# Select the first station for analysis
station_id <- my_stations$id[1]
cat("\nAnalyzing station:", my_stations$name[1], "\n\n")

# ============================================================================
# DOWNLOAD DETECTION DATA
# ============================================================================

# Download last 30 days of detections with high confidence
end_date <- Sys.Date()
start_date <- end_date - 30

cat("Downloading detections from", as.character(start_date), 
    "to", as.character(end_date), "\n")

detections <- bw_get_detections(
  station_id = station_id,
  start_date = start_date,
  end_date = end_date,
  min_confidence = 0.8,  # Only high-confidence detections
  verbose = TRUE
)

cat("\nTotal detections:", nrow(detections), "\n")

# ============================================================================
# SPECIES ANALYSIS
# ============================================================================

# Summarize by species
species_summary <- bw_summarize_species(detections, min_detections = 3)

cat("\nSpecies summary:\n")
print(species_summary)

# Plot top 10 species
if (nrow(species_summary) > 0) {
  top_10 <- head(species_summary, 10)
  
  p1 <- ggplot(top_10, aes(x = reorder(species_common_name, n_detections), 
                            y = n_detections)) +
    geom_col(fill = "steelblue") +
    coord_flip() +
    labs(title = "Top 10 Most Detected Species",
         x = "Species", y = "Number of Detections") +
    theme_minimal()
  
  print(p1)
  ggsave("top_species.png", p1, width = 8, height = 6)
  cat("\nSaved plot: top_species.png\n")
}

# ============================================================================
# TEMPORAL PATTERNS
# ============================================================================

# Daily detection patterns
daily_summary <- bw_summarize_temporal(detections, period = "day")

cat("\nDaily summary:\n")
print(head(daily_summary))

# Plot daily pattern
if (nrow(daily_summary) > 0) {
  p2 <- ggplot(daily_summary, aes(x = time_period, y = n_detections)) +
    geom_line(color = "steelblue", size = 1) +
    geom_point(color = "steelblue", size = 2) +
    labs(title = "Daily Bird Detection Activity",
         x = "Date", y = "Number of Detections") +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  
  print(p2)
  ggsave("daily_pattern.png", p2, width = 10, height = 6)
  cat("\nSaved plot: daily_pattern.png\n")
}

# ============================================================================
# TIME OF DAY ANALYSIS
# ============================================================================

# Add hour column for time-of-day analysis
detections <- detections %>%
  mutate(hour = lubridate::hour(timestamp))

hourly_pattern <- detections %>%
  group_by(hour) %>%
  summarise(
    n_detections = n(),
    n_species = n_distinct(species_id)
  )

cat("\nHourly pattern:\n")
print(hourly_pattern)

# Plot hourly pattern
if (nrow(hourly_pattern) > 0) {
  p3 <- ggplot(hourly_pattern, aes(x = hour, y = n_detections)) +
    geom_col(fill = "darkgreen") +
    scale_x_continuous(breaks = 0:23) +
    labs(title = "Detection Activity by Hour of Day",
         x = "Hour (24-hour format)", y = "Number of Detections") +
    theme_minimal()
  
  print(p3)
  ggsave("hourly_pattern.png", p3, width = 10, height = 6)
  cat("\nSaved plot: hourly_pattern.png\n")
}

# ============================================================================
# DAWN CHORUS ANALYSIS
# ============================================================================

# Focus on dawn chorus (5 AM - 9 AM)
dawn_detections <- bw_filter_time_of_day(detections, start_hour = 5, end_hour = 9)
dawn_species <- bw_summarize_species(dawn_detections)

cat("\nDawn chorus (5 AM - 9 AM):\n")
cat("Total detections:", nrow(dawn_detections), "\n")
cat("Number of species:", nrow(dawn_species), "\n")
print(head(dawn_species, 10))

# ============================================================================
# EXPORT DATA
# ============================================================================

# Save detection data
write.csv(detections, "detections.csv", row.names = FALSE)
write.csv(species_summary, "species_summary.csv", row.names = FALSE)
write.csv(daily_summary, "daily_summary.csv", row.names = FALSE)

cat("\n✓ Exported data files:\n")
cat("  - detections.csv\n")
cat("  - species_summary.csv\n")
cat("  - daily_summary.csv\n")

# Save as RDS for later R use
saveRDS(detections, "detections.rds")
cat("  - detections.rds\n")

# ============================================================================
# SUMMARY REPORT
# ============================================================================

cat("\n" , rep("=", 70), "\n", sep = "")
cat("ANALYSIS COMPLETE\n")
cat(rep("=", 70), "\n", sep = "")
cat("\nStation:", my_stations$name[1], "\n")
cat("Date range:", as.character(start_date), "to", as.character(end_date), "\n")
cat("Total detections:", nrow(detections), "\n")
cat("Species detected:", length(unique(detections$species_id)), "\n")
cat("Mean confidence:", round(mean(detections$confidence), 3), "\n")
cat("\nFiles created:\n")
cat("  - 3 CSV files\n")
cat("  - 1 RDS file\n")
cat("  - 3 PNG plots\n")
cat("\n")
