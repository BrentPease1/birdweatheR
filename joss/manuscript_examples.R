library(birdweatheR)
library(data.table)
library(ggplot2)
library(MetBrewer)
library(terra)
library(geodata)
library(here)
library(GLMMadaptive)
library(cowplot)
library(sf)
## connect to API
connect_birdweather()

# EXAMPLE APPLICATIONS ####
# 1. Wood Thrush Spring Migration ####

## Load dataset: WOTH detections from 2025-03-01 to 2025-05-31, BirdNET conf >= 0.6

# -- repro code:
# woth_id <- find_species("Wood Thrush")$species_id
# woth <- get_detections(
#   from           = "2025-03-01T00:00:00.000Z",
#   to             = "2025-05-31T00:00:00.000Z",
#   species_ids    = woth_id,
#   confidence_gte = 0.6,
#   continents     = "North America"
# )

data(woth)

# lubridates
woth[, date := as.Date(timestamp)]

# calculate median latitude of detections by date
median_lat <- woth[, .(median_lat = median(station_lat, na.rm = TRUE)),
                   by = date]
# plot
paper_pal <- MetBrewer::met.brewer('Morgenstern')

(spr_migration <- ggplot(median_lat, aes(x = date, y = median_lat)) +
  geom_smooth(method = "gam",
              color = paper_pal[2],
              fill = paper_pal[7]) +
  annotate(
    "text",
    x     = as.Date("2025-03-20"),
    y     = 12,
    label = "Wintering grounds\n(Central America)",
    size  = 3.5,
    color = "gray40"
  ) +
  annotate(
    "text",
    x     = as.Date("2025-05-12"),
    y     = 45,
    label = "Breeding grounds\n(Eastern N. America)",
    size  = 3.5,
    color = "gray40"
  ) +
  labs(x        = NULL, y        = "Median Latitude (°N)", ) +
  theme_minimal() +
  theme(axis.text = element_text(size = 14),
        axis.title = element_text(size = 16)))

ggsave(filename = "fig2_woth_spr_migration.png", plot = spr_migration, device = "png",
       path = here::here("manuscript_examples"), width = 4, height = 4, dpi = 300)

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# 2. WOTH Activity Patterns ####
data(woth)
# Restrict to PUC stations active for >= 30 days
woth[, date := as.Date(timestamp)]
woth[, month   := month(date)]
woth[, n_days := uniqueN(date), by = .(station_id, month)]
woth_puc <- woth[station_type == "puc" & n_days > 30]

# Parse timestamps and look up local timezone per station
d <- woth_puc[, .(timestamp, station_id, station_lat, station_lon)]
d[, zone      := lutz::tz_lookup_coords(station_lat, station_lon, method = "fast")]
d[, timestamp := lubridate::parse_date_time(timestamp, orders = "ymdHMSz")]
d[, date      := as.Date(timestamp)]
d <- d[!is.na(timestamp)]

station_tz <- d[, .(station_lat  = station_lat[1],
                    station_lon  = station_lon[1],
                    station_zone = zone[1]),
                by = station_id]

min_date <- min(d$date)
max_date <- max(d$date)

# Build complete 30-minute occasion grid per station
occasions <- vector("list", nrow(station_tz))
for (i in seq_len(nrow(station_tz))) {
  tz_i <- station_tz$station_zone[i]
  starts <- seq(
    from = lubridate::ymd_hms(paste(min_date, "00:00:00"), tz = tz_i),
    to   = lubridate::ymd_hms(paste(max_date, "00:00:00"), tz = tz_i),
    by   = "30 min"
  )
  occasions[[i]] <- data.table::data.table(
    station_id = station_tz$station_id[i],
    start      = starts,
    end        = c(starts[-1], starts[length(starts)] + lubridate::minutes(30))
  )
}

# bring it all together, call it a bunch of zeros then update
occ <- data.table::rbindlist(occasions)
occ[, capt  := 0L]
occ[, start := lubridate::with_tz(start, "UTC")]
occ[, end   := lubridate::with_tz(end,   "UTC")]

# join occ and d, mark intervals containing >= 1 detection
occ[d, capt := 1L,
    on = .(station_id,
           start <= timestamp,
           end   >  timestamp)]

# Interval midpoint and integer time-of-day bin (1-48)
occ[, mid      := start + as.numeric(difftime(end, start, units = "secs")) / 2]
occ[, mid_time := as.numeric(difftime(mid, lubridate::floor_date(mid, "day"),
                                      units = "mins"))]

# Summarise success/failure by station and time-of-day bin
final <- occ[, .(success = sum(capt),
                 failure = .N - sum(capt)),
             by = .(station_id, mid_time)]
final[, time := .GRP, by = mid_time]  # integer 1-48 circular predictor

# Join station coordinates
final <- station_tz[, .(station_id, station_lat, station_lon)][final, on = "station_id"]


# Download HFI raster (cached after first run)
if(!dir.exists(here('manuscript_examples/landuse'))){
  hfi_rast <- geodata::footprint(year = 2009, path = tempdir())
} else{
  hfi_rast <- rast(here('manuscript_examples/landuse/wildareas-v3-2009-human-footprint_geo.tif'))
}

# Extract HFI at station locations
stations_vect  <- terra::vect(as.data.frame(station_tz),
                              geom = c("station_lon", "station_lat"),
                              crs  = "EPSG:4326")
station_tz$hfi <- terra::extract(hfi_rast, stations_vect)[, 2]

# Join HFI onto modelling dataset
final <- final[station_tz[, .(station_id, hfi)], on = "station_id"]

# fit model following Innarilli et al. 2024
if(!file.exists(here('manuscript_examples/woth_activity_m1.Rda'))){
  m1 <-  GLMMadaptive::mixed_model(
    fixed = cbind(success, failure) ~
      hfi * (
        cos(2 * pi * time / 48) + sin(2 * pi * time / 48) +
          cos(2 * pi * time / 24) + sin(2 * pi * time / 24)
      ),
    random = ~ cos(2 * pi * time / 48) + sin(2 * pi * time / 48) +
      cos(2 * pi * time / 24) + sin(2 * pi * time / 24) || station_id,
    data = final,
    family = binomial(),
    iter_EM = 0
  )
  save(m1, file = here('manuscript_examples/woth_activity_m1.Rda'))
} else{
  load(here("manuscript_examples/woth_activity_m1.Rda"))
}


# plot marginal curves

# create new dataset
newdat <- expand.grid(
  time = seq(0, 48, length.out = 96), hfi = quantile(final$hfi, probs = c(0.1, 0.9))
)
# calculate marginal effects
marg_eff <- GLMMadaptive::effectPlotData(m1, newdat, marginal = TRUE)
marg_eff <- data.table::as.data.table(marg_eff)
marg_eff[, c("pred", "low", "upp") := lapply(.SD, plogis), .SDcols = c("pred", "low", "upp")]
marg_eff[, time := time / 2]
marg_eff[, hfi := factor(marg_eff$hfi,
                         labels = c("Low human footprint", "High human footprint"))]

# plot
paper_pal <- MetBrewer::met.brewer('Morgenstern')
(woth_activity_plot <- ggplot(marg_eff, aes(
  x = time,
  y = pred,
  color = factor(hfi),
  fill = factor(hfi)
)) +
  geom_ribbon(aes(ymin = low, ymax = upp), alpha = 0.25, color = NA) +
  geom_line(linewidth = 1.5) +
  scale_x_continuous(limits = c(0, 24),
                     breaks = c(0, 4, 8, 12, 16, 20, 24)) +
  scale_color_manual(values = paper_pal[c(2, 7)]) +
  scale_fill_manual(values = paper_pal[c(2, 7)]) +
  labs(x = "Time of Day (Hour)",
       y = "Probability of activity",
       color = "HFI",
       fill = "HFI") +
    theme_minimal() +
  theme(
    axis.line = element_line(color = "black", linewidth = 0.2),
    axis.title = element_text(color = "black", size = 16),
    axis.text = element_text(color = "black", size = 14),
    legend.text = element_text(size = 14),
    legend.title = element_text(size = 16),
    legend.position = 'top'
  ))
ggsave(filename = here('manuscript_examples/fig3_woth_activity_plot.png'), plot = woth_activity_plot,
       device = 'png', width = 6, height = 4, dpi = 300)

# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
# -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

# 3. Eclipse Analysis ####

data(total_eclipse)
data(eclipse_light_data)
data(eclipse_env_data)
# create data
# To reproduce from the API:
# connect_birdweather()
# total_eclipse <- get_detections(
#   from           = "2024-04-08T00:00:00.000Z",
#   to             = "2024-04-09T00:00:00.000Z",
#   ne             = list(lat = 42.639347, lon = -79.672852),
#   sw             = list(lat = 34.331340, lon = -94.570313),
#   confidence_gte = 0.6,
#   station_types  = "puc"
# )
#
# station_ids <- unique(total_eclipse$station_id)
# eclipse_light_data <- get_light_data(
#   station_id = station_ids,
#   from       = "2024-04-08T00:00:00.000Z",
#   to         = "2024-04-09T00:00:00.000Z"
# )
# eclipse_env_data <- get_environment_data(
#   station_id = station_ids,
#   from       = "2024-04-08T00:00:00.000Z",
#   to         = "2024-04-09T00:00:00.000Z"
# )

# prep data times
eclipse_light_data[, datetime := as.POSIXct(timestamp,
                                            format = "%Y-%m-%dT%H:%M:%S",
                                            tz = "America/Chicago")]
total_eclipse[, datetime := as.POSIXct(timestamp,
                                       format = "%Y-%m-%dT%H:%M:%S",
                                       tz = "America/Chicago")]

eclipse_env_data[, datetime := as.POSIXct(timestamp,
                                          format = "%Y-%m-%dT%H:%M:%S",
                                          tz = "America/Chicago")]

# read in eclipse path shapefile
total_center <- st_read(here('manuscript_examples/2024eclipse_shapefiles/center.shp'))
total_upath_lo <- st_read(here('manuscript_examples/2024eclipse_shapefiles/upath_lo.shp'))

eclipse_locs <- total_eclipse[!duplicated(station_id), .(station_id, station_lon, station_lat)]
eclipse_locs <- st_as_sf(eclipse_locs, coords = c("station_lon", "station_lat"), crs = 4326)

# puc proximity to path
eclipse_dist_mat <- st_distance(eclipse_locs, total_center)
eclipse_locs$dist_to_center <- eclipse_dist_mat[,1]

# is puc within path?
eclipse_locs$within_path <- ifelse(st_intersects(eclipse_locs, total_upath_lo), 'within_path', 'outside_path')
eclipse_locs$within_path <- ifelse(is.na(eclipse_locs$within_path), "outside_path", eclipse_locs$within_path)
eclipse_locs <- as.data.table(st_drop_geometry(eclipse_locs))


within_path_ids <- eclipse_locs[within_path == 'within_path', station_id]

# -- --
# 4-minute bin helper
bin4 <- function(dt) {
  as.POSIXct(
    paste0(format(dt, "%Y-%m-%d %H:"),
           sprintf("%02d", (as.integer(format(dt, "%M")) %/% 4) * 4),
           ":00"),
    tz = "America/Chicago"
  )
}

# 1-minute bin helper
bin1 <- function(dt) {
  as.POSIXct(
    paste0(format(dt, "%Y-%m-%d %H:"),
           sprintf("%02d", (as.integer(format(dt, "%M")) %/% 1) * 1),
           ":00"),
    tz = "America/Chicago"
  )
}

# Filter to daytime window and totality stations
eclipse_day_light <- eclipse_light_data[
  station_id %in% within_path_ids &
    datetime >= as.POSIXct("2024-04-08 13:00:00", tz = "America/Chicago") &
    datetime <= as.POSIXct("2024-04-08 15:00:00", tz = "America/Chicago")
]

eclipse_day_env <- eclipse_env_data[
  station_id %in% within_path_ids &
    datetime >= as.POSIXct("2024-04-08 13:00:00", tz = "America/Chicago") &
    datetime <= as.POSIXct("2024-04-08 15:00:00", tz = "America/Chicago")
]

eclipse_day_dets <- total_eclipse[
  station_id %in% within_path_ids &
    datetime >= as.POSIXct("2024-04-08 13:00:00", tz = "America/Chicago") &
    datetime <= as.POSIXct("2024-04-08 15:00:00", tz = "America/Chicago")
]

# Count prop community vocalizing per 4 minute window
# Per-station community size (denominator)
community_size <- eclipse_day_dets[,
                                   .(n_species_total = uniqueN(common_name)),
                                   by = station_id]

# Per-station, per-bin species richness (numerator)
bin_richness <- eclipse_day_dets[,
                                 .(n_species_bin = uniqueN(common_name)),
                                 by = .(station_id, bin = bin4(datetime))]

# Join and compute proportion
bin_richness <- community_size[bin_richness, on = "station_id"]
bin_richness[, prop_vocalizing := n_species_bin / n_species_total]

# Average across stations per bin
mean_prop <- bin_richness[,
                          .(mean_prop = mean(prop_vocalizing, na.rm = TRUE),
                            se_prop   = sd(prop_vocalizing, na.rm = TRUE) / sqrt(.N)),
                          by = bin]
# light and env bins too
light_bins <- eclipse_day_light[,
                                .(mean_clear = mean(clear, na.rm = TRUE)),
                                by = .(bin = bin1(datetime))]

env_bins <- eclipse_day_env[,
                                .(mean_hum = mean(humidity, na.rm = TRUE)),
                                by = .(bin = bin1(datetime))]


# Plot
paper_pal <- MetBrewer::met.brewer('Morgenstern')

(p1 <- ggplot(mean_prop, aes(x = bin, y = mean_prop)) +
  geom_line(color = paper_pal[2], alpha = 0.2) +
  geom_smooth(color = paper_pal[2], se = FALSE, span = 0.1) +
  geom_vline(
    xintercept = as.POSIXct("2024-04-08 14:01:20", tz = "America/Chicago"),
    color = "gray20", linetype = "dashed"
  ) +
  annotate("text",
           x     = as.POSIXct("2024-04-08 14:01:20", tz = "America/Chicago"),
           y     = max(det_bins$prop_vocalizing, na.rm = TRUE) * 0.95,
           label = "Totality", color = "gray20", hjust = -0.1, size = 4) +
  labs(
    x = NULL,
    y = "Proportion of community vocalizing"
  ) +
  theme_minimal() +
    theme(axis.text = element_text(size = 14),
          axis.title = element_text(size = 14)))

# light data
(p2 <- ggplot(light_bins, aes(x = bin, y = mean_clear)) +
  geom_line(color = paper_pal[6]) +
  geom_vline(
    xintercept = as.POSIXct("2024-04-08 14:01:20", tz = "America/Chicago"),
    color = "gray20", linetype = "dashed"
  ) +
  labs(
    x        = NULL,
    y        = "Mean Clear Light on within-path PUCs",
  ) +
  theme_minimal() +
  theme(axis.text = element_text(size = 14),
        axis.title = element_text(size = 14)))

# temperature
(p3 <- ggplot(env_bins, aes(x = bin, y = mean_hum)) +
    geom_line(color = paper_pal[8]) +
    geom_vline(
      xintercept = as.POSIXct("2024-04-08 14:01:20", tz = "America/Chicago"),
      color = "gray20", linetype = "dashed"
    ) +
    labs(
      x        = NULL,
      y        = "Mean Humidity on within-path PUCs",
    ) +
    theme_minimal() +
  theme(axis.text = element_text(size = 14),
        axis.title = element_text(size = 14)))

# combine
bottom_row <- plot_grid(p2, p3, nrow = 1, labels = list("B", "C"))

out <- plot_grid(
  p1, bottom_row,
  nrow = 2, labels = list("A", "", "")
)

save_plot(
  here("manuscript_examples/fig4_eclipse.png"),
  out,
  base_height = 8,
  base_width = 12
)
