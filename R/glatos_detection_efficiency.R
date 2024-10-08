## ----load packages, message = FALSE-------------------------------------------------------------------------------------------------------------------
# ---- Bring in R packages ----
{
  library(dplyr)
  library(ggplot2)
  library(glatos)
  library(mapview)
  library(purrr)
  library(sf)
}


## ----results = 'hide'---------------------------------------------------------------------------------------------------------------------------------
#| title: get example data from glatos

# get path to example receiver_locations file
rec_file <- system.file("extdata",
  "sample_receivers.csv",
  package = "glatos"
)

# note that code above is needed to find the example file
# for real glatos data, use something like below
# rec_file <- "c:/path_to_file/GLATOS_receiverLocations_20150321_132242.csv"

rcv <- read_glatos_receivers(rec_file)

glimpse(rcv)


## ----messages = FALSE---------------------------------------------------------------------------------------------------------------------------------
#| title: convert to sf and filter out array and specific station

rcv_osc_sf <- rcv %>%
  st_as_sf(
    coords = c("deploy_long", "deploy_lat"),
    crs = 4326
  ) %>%
  filter(glatos_array %in% "OSC")

# view in mapview
mapview(rcv_osc_sf)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: filter out 12

rcv_osc_sf_12 <- rcv_osc_sf %>%
  filter(station_no %in% 12) %>%
  st_transform(crs = 32617)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: create buffer rings

# first create a data frame of distances to iterate over

dists <- data.frame(
  distance = c(100, 250, 500, 750)
)
# next we will split the data frame by distance and iterate over it using map
buffer_rings <- dists %>%
  split(.$distance) %>%
  map(~ st_buffer(dist = .x$distance, rcv_osc_sf_12)) %>%
  bind_rows(.id = "distance") %>%
  st_cast("LINESTRING", warn = FALSE) %>%
  dplyr::select(distance, glatos_array, station_no, ins_serial_no, geometry)
# now view buffer rings
mapview(rcv_osc_sf) +
  mapview(buffer_rings)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: transform, view and filter

buffer_rings_pts <- buffer_rings %>%
  st_cast("POINT", warn = FALSE) %>%
  mutate(
    id = 1:nrow(.)
  ) %>%
  dplyr::select(id, distance:geometry)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
mapview(rcv_osc_sf) +
  mapview(buffer_rings_pts)


## ----results = 'hide'---------------------------------------------------------------------------------------------------------------------------------
deploy_sites <- buffer_rings_pts %>%
  st_transform(crs = 4326) %>%
  filter(id %in% c(
    4, 49, 155,
    407, 456, 472,
    671, 696, 720,
    835, 876, 920
  )) %>%
  rename(
    receiver_serial_no = ins_serial_no
  ) %>%
  mutate(
    deploy_date_time = NA,
    deploy_lat = NA,
    deploy_long = NA,
    bottom_depth = NA,
    riser_length = NA,
    instrument_depth = NA,
    ins_model_number = NA,
    ins_serial_no = NA,
    transmitter = NA,
    transmitter_model = NA,
    deployed_by = NA,
    recovered = NA,
    recover_date_time = NA,
    recover_lat = NA,
    recover_long = NA,
    data_downloaded = NA,
    download_date_time = NA,
    comments = NA,
    expect_deploy_lat = st_coordinates(.)[, "Y"],
    expect_deploy_long = st_coordinates(.)[, "X"],
    comments = NA
  ) %>%
  dplyr::select(
    id:receiver_serial_no,
    deploy_date_time:expect_deploy_long, geometry
  )


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: save excel and gpx file
#| echo: TRUE
#| eval: FALSE

## # drop geometry (coerce to data.frame)
## deploy_sites_df <- st_drop_geometry(deploy_sites)
## 
## # write xlsx file
## openxlsx::write.xlsx(deploy_sites_df, "YOUR_FILE_PATH.xlsx")
## 
## # save as gpx
## st_write(deploy_sites, "YOUR_FILE_PATH.gpx",
##   driver = "GPX",
##   dataset_options = "GPX_USE_EXTENSIONS=YES"
## )


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| echo: TRUE
#| eval: FALSE

## det_summary <- dets %>%
##   group_by(station, dets_expected, tag_serial_name) %>%
##   summarise(
##     dets_heard = n()
##   ) %>%
##   ungroup() %>%
##   mutate(
##     dets_eff = dets_heard / dets_expected,
##     dets_eff_perc = (dets_heard / dets_expected) * 100
##   )


## ----reload, eval = FALSE, message = FALSE------------------------------------------------------------------------------------------------------------
## # ---- Bring in R packages ----
## {
##   library(dplyr)
##   library(ggplot2)
##   library(glatos)
##   library(mapview)
##   library(purrr)
##   library(sf)
## }


## -----------------------------------------------------------------------------------------------------------------------------------------------------
# get path to example receiver_locations file
rec_file <- system.file("extdata",
  "sample_receivers.csv",
  package = "glatos"
)

# note that code above is needed to find the example file
# for real glatos data, use something like below
# rec_file <- "c:/path_to_file/GLATOS_receiverLocations_20150321_132242.csv"

rcv <- read_glatos_receivers(rec_file)

glimpse(rcv)


## ----messages = FALSE---------------------------------------------------------------------------------------------------------------------------------
#| title: convert to sf and filter out array and specific station

rcv_osc_sf <- rcv %>%
  st_as_sf(
    coords = c("deploy_long", "deploy_lat"),
    crs = 4326
  ) %>%
  filter(glatos_array %in% "OSC")

# view in mapview
mapview(rcv_osc_sf)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: filter out 12

rcv_osc_sf_12 <- rcv_osc_sf %>%
  filter(station_no %in% 12) %>%
  st_transform(crs = 32617)


## ----results = 'hide'---------------------------------------------------------------------------------------------------------------------------------
#| title: evaluate data

# ----- uncomment the lines below to bring in your data ----
#
# and replace with the file path and name of detection efficiency
# file (replace "YOUR_DET_EFF.csv")
#
# det_eff <- readr::read_csv("YOUR_DET_EFF.csv")
#
# glimpse(det_eff)

# view sample detection efficiency data

sample_detection_efficiency

glimpse(sample_detection_efficiency)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: use detection_range_model

# third order polynomial: ave_percent is a whole number
m <- detection_range_model(
  avg_percent ~ -1 + distance_m + I(distance_m^2) +
    I(distance_m^3) + offset(intercept),
  data = sample_detection_efficiency,
  percentage = c(10, 50, 90),
  link = "polynomial",
  model_frame = "data_frame"
)


## ----warning=FALSE------------------------------------------------------------------------------------------------------------------------------------
#| title: use detection_range_model

# logit model: aver percent is in decimal form

m1 <- detection_range_model(avg_percent_d ~ distance_m,
  data = sample_detection_efficiency,
  percentage = c(10, 50, 90),
  link = "logit",
  summary_stats = TRUE
)

# probit model: aver percent is in decimal form

m2 <- detection_range_model(avg_percent_d ~ distance_m,
  data = sample_detection_efficiency,
  percentage = c(10, 50, 90),
  link = "probit",
  summary_stats = TRUE
)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: view poly
m


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: view logit
m1


## -----------------------------------------------------------------------------------------------------------------------------------------------------
#| title: view provit
m2


## ----warning = FALSE, message = FALSE-----------------------------------------------------------------------------------------------------------------
#| title: plot models
#| fig-height: 5
#| fig-width: 7
ggplot() +
  geom_point(
    data = sample_detection_efficiency,
    aes(x = distance_m, y = avg_percent),
    size = 3
  ) +
  geom_hline(yintercept = c(10, 50, 90), linetype = 2) +
  geom_smooth(
    data = sample_detection_efficiency,
    aes(x = distance_m, y = avg_percent),
    method = "lm",
    linewidth = 1,
    formula = y ~ -1 + x + I(x^2) +
      I(x^3),
    method.args = list(offset = sample_detection_efficiency$intercept),
    colour = "#8da0cb", se = FALSE
  ) +
  scale_y_continuous(breaks = seq(0, 100, 20)) +
  theme_bw(base_size = 15) +
  theme(
    panel.grid = element_blank()
  ) +
  labs(
    x = "Distance (m)",
    y = "Detection efficency (%)"
  )


## ----warning = FALSE, message = FALSE-----------------------------------------------------------------------------------------------------------------
#| title: plot logist and probit models
#| fig-height: 5
#| fig-width: 7
ggplot() +
  geom_point(
    data = sample_detection_efficiency,
    aes(x = distance_m, y = avg_percent_d),
    size = 3
  ) +
  geom_hline(yintercept = c(0.10, 0.50, 0.90), linetype = 2) +
  geom_smooth(
    data = sample_detection_efficiency,
    aes(x = distance_m, y = avg_percent_d),
    method = "glm",
    linewidth = 1,
    method.args = list(family = binomial(link = "logit")),
    colour = "#66c2a5", se = FALSE
  ) +
  geom_smooth(
    data = sample_detection_efficiency,
    aes(x = distance_m, y = avg_percent_d),
    method = "glm",
    linewidth = 1,
    method.args = list(family = binomial(link = "probit")),
    colour = "#fc8d62", se = FALSE
  ) +
  scale_y_continuous(breaks = seq(0, 1, 0.20)) +
  theme_bw(base_size = 15) +
  theme(
    panel.grid = element_blank()
  ) +
  labs(
    x = "Distance (m)",
    y = "Detection efficency (%)"
  )


## ----warning = FALSE----------------------------------------------------------------------------------------------------------------------------------
#| title: create redployment ring
redeploy_loc <- st_buffer(dist = 370, rcv_osc_sf_12) %>%
  st_cast("LINESTRING") %>%
  mutate(
    distance = 370
  ) %>%
  dplyr::select(distance, glatos_array, station_no, ins_serial_no, geometry)
# now view redeployment rings
mapview(rcv_osc_sf) +
  mapview(redeploy_loc)


## ----warning = FALSE----------------------------------------------------------------------------------------------------------------------------------
#| title: tranform, view and filter

redeploy_loc_pts <- redeploy_loc %>%
  st_cast("POINT") %>%
  mutate(
    id = 1:nrow(.)
  ) %>%
  dplyr::select(id, distance:geometry)


## -----------------------------------------------------------------------------------------------------------------------------------------------------
mapview(rcv_osc_sf) +
  mapview(redeploy_loc_pts)


## ----results = 'hide'---------------------------------------------------------------------------------------------------------------------------------
redeploy_sites <- redeploy_loc_pts %>%
  st_transform(crs = 4326) %>%
  filter(id %in% c(116, 161, 201)) %>%
  rename(
    receiver_serial_no = ins_serial_no
  ) %>%
  mutate(
    deploy_date_time = NA,
    deploy_lat = NA,
    deploy_long = NA,
    bottom_depth = NA,
    riser_length = NA,
    instrument_depth = NA,
    ins_model_number = NA,
    ins_serial_no = NA,
    transmitter = NA,
    transmitter_model = NA,
    deployed_by = NA,
    recovered = NA,
    recover_date_time = NA,
    recover_lat = NA,
    recover_long = NA,
    data_downloaded = NA,
    download_date_time = NA,
    comments = NA,
    expect_deploy_lat = st_coordinates(.)[, "Y"],
    expect_deploy_long = st_coordinates(.)[, "X"],
    comments = NA
  ) %>%
  dplyr::select(
    id:receiver_serial_no,
    deploy_date_time:expect_deploy_long, geometry
  )


## ----eval = FALSE-------------------------------------------------------------------------------------------------------------------------------------
#| title: save excel and gpx file

## # drop geometry (coerce to data.frame)
## redeploy_sites_df <- st_drop_geometry(redeploy_sites)
## 
## # write xlsx file
## openxlsx::write.xlsx(redeploy_sites_df, "YOUR_FILE_PATH2.xlsx")
## 
## # save as gpx
## st_write(redeploy_sites, "YOUR_FILE_PATH2.gpx",
##   driver = "GPX",
##   dataset_options = "GPX_USE_EXTENSIONS=YES"
## )

