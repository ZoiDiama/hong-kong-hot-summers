# Hong Kong's summers are getting hotter and longer
# Climate at the Hong Kong Observatory, 1953–2025, built entirely in R.
# Data: Hong Kong Observatory, via data.gov.hk (daily maximum temperature,
# daily mean temperature, daily total rainfall)

# 1. LIBRARIES -------------------------------------------------------------
library(tidyverse)
library(ggtext)
library(patchwork)
library(showtext)

font_add_google("Playfair Display", family = "serif_t")
font_add_google("Lato", family = "lato")
showtext_auto()
showtext_opts(dpi = 288)

bg    <- "#FAF6F0"
ink   <- "#1F1F1F"; muted <- "#555555"; faint <- "#8A8A8A"
hot   <- "#D7462B"     # very hot days
warm  <- "#F2C6A0"
pale  <- "#EFE6DA"     # all other days
rain  <- "#1F5E8C"

# 2. DATA ------------------------------------------------------------------
# All three files have the same layout: 2 title lines, a header, then
# Year, Month, Day, Value, completeness flag; notes at the bottom.
read_hko <- function(file) {
  read_csv(file, skip = 3, col_names = c("year", "month", "day", "value", "flag"),
           col_types = "ccccc", show_col_types = FALSE) |>
    mutate(across(c(year, month, day), \(x) suppressWarnings(as.numeric(x)))) |>
    filter(!is.na(year), !is.na(day)) |>
    mutate(value = if_else(value == "Trace", "0", value),           # rainfall: trace = 0 mm
           value = suppressWarnings(as.numeric(value)),
           date  = make_date(year, month, day)) |>
    filter(year >= 1953, year <= 2025)
}
tmax <- read_hko("data/CLMMAXT_HKO_.csv")
tmean <- read_hko("data/CLMTEMP_HKO_.csv")
rf    <- read_hko("data/daily_HKO_RF_ALL.csv")

# 3. INDICATORS ------------------------------------------------------------
# Very hot day: daily maximum of 33 °C or more (Hong Kong Observatory definition)
hot_days <- tmax |>
  mutate(very_hot = value >= 33, doy = yday(date))
hot_year <- hot_days |> group_by(year) |> summarise(n = sum(very_hot))

decade_avg <- \(d, var, from, to) mean(d[[var]][d$year >= from & d$year <= to])
hot_50s <- decade_avg(hot_year, "n", 1953, 1959)
hot_now <- decade_avg(hot_year, "n", 2020, 2025)
hot_10s <- decade_avg(hot_year, "n", 2010, 2019)

mean_year <- tmean |> group_by(year) |> summarise(t = mean(value, na.rm = TRUE))
t_50s <- decade_avg(mean_year, "t", 1953, 1959)
t_now <- decade_avg(mean_year, "t", 2020, 2025)

wet_year <- rf |> group_by(year) |> summarise(max = max(value, na.rm = TRUE),
                                             day = date[which.max(value)])
wettest <- wet_year |> slice_max(max, n = 1)

# Season: first and last very hot day, average for the 1950s and 2020s
season <- hot_days |> filter(very_hot) |> group_by(year) |>
  summarise(first = min(doy), last = max(doy))
lab_doy <- \(d) format(as.Date(round(d) - 1, origin = "2001-01-01"), "%e %b") |> str_squish()
s50  <- season |> filter(year <= 1959) |> summarise(across(c(first, last), mean))
snow <- season |> filter(year >= 2020) |> summarise(across(c(first, last), mean))

# 4. HERO: radial calendar of very hot days --------------------------------
inner <- 22                                   # empty space in the middle
radial <- hot_days |> mutate(r = year - 1953 + inner)
month_starts <- yday(make_date(2001, 1:12, 1))
month_lab <- tibble(doy = month_starts + 15, lab = month.abb)
ring_lab <- tibble(year = c(1953, 1970, 1990, 2010, 2025)) |> mutate(r = year - 1953 + inner)

p_hero <- ggplot(radial) +
  geom_tile(aes(doy, r, fill = very_hot), width = 1, height = 1) +
  geom_vline(xintercept = month_starts - 0.5, colour = bg, linewidth = 0.35) +
  geom_text(data = month_lab, aes(doy, max(radial$r) + 3.5, label = lab), family = "lato",
            size = 3, colour = muted) +
  geom_label(data = ring_lab, aes(x = 2, y = r, label = year), family = "lato", size = 2.4,
             colour = muted, fill = bg, label.size = 0, label.padding = unit(0.6, "pt")) +
  annotate("text", x = 0, y = 0, label = "1953\nat the centre,\n2025 at the edge",
           family = "lato", size = 2.6, colour = faint, lineheight = 0.95) +
  scale_fill_manual(values = c(`TRUE` = hot, `FALSE` = pale), guide = "none") +
  scale_x_continuous(limits = c(0.5, 366.5), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, max(radial$r) + 4), expand = c(0, 0)) +
  coord_polar(start = 0) +
  labs(title = "Every day since 1953",
       subtitle = paste0("Each ring is one year, from 1953 in the centre to 2025 at the edge, ",
                         "and each segment is one day. <span style='color:", hot,
                         "'>**Red**</span> marks a very hot day. The red band grows thicker ",
                         "and spreads into May and October in recent years.")) +
  theme_void(base_family = "lato") +
  theme(plot.title = element_text(family = "serif_t", size = 15, colour = ink, margin = margin(b = 3)),
        plot.subtitle = element_textbox_simple(size = 9.5, colour = muted, margin = margin(b = 4)),
        plot.title.position = "plot",
        plot.background = element_rect(fill = bg, colour = NA))

# 5. VERY HOT DAYS PER YEAR -------------------------------------------------
p_hot <- ggplot(hot_year, aes(year, n)) +
  annotate("segment", x = 1953, xend = 1959, y = hot_50s, yend = hot_50s, colour = ink, linewidth = 0.5) +
  annotate("segment", x = 2020, xend = 2025, y = hot_now, yend = hot_now, colour = ink, linewidth = 0.5) +
  geom_col(aes(fill = year >= 2020), width = 0.75) +
  annotate("text", x = 1953, y = hot_50s + 6, hjust = 0, label = paste0("1950s: ", round(hot_50s), " a year"),
           family = "lato", size = 2.8, colour = ink, fontface = "bold") +
  annotate("text", x = 2022.5, y = hot_now + 6, label = paste0("2020s: ", round(hot_now)),
           family = "lato", size = 2.8, colour = ink, fontface = "bold", hjust = 1) +
  scale_fill_manual(values = c(`TRUE` = hot, `FALSE` = warm), guide = "none") +
  scale_x_continuous(breaks = c(1953, 1970, 1990, 2010, 2025)) +
  scale_y_continuous(breaks = seq(0, 60, 20), expand = expansion(mult = c(0, 0.1))) +
  labs(title = "Four times as many very hot days",
       subtitle = "Number of very hot days each year. Few until 2010, then a steep rise: around 50 a year since 2020.") +
  theme_minimal(base_family = "lato") +
  theme(plot.title = element_text(family = "serif_t", size = 13, colour = ink, margin = margin(b = 4)),
        plot.subtitle = element_textbox_simple(size = 8.5, colour = muted, lineheight = 1.2, margin = margin(t = 6, b = 8)),
        plot.title.position = "plot",
        axis.title = element_blank(), axis.text = element_text(size = 7.5, colour = faint),
        panel.grid = element_blank(),
        panel.grid.major.y = element_line(colour = "#E4DCD0", linewidth = 0.3),
        plot.background = element_rect(fill = bg, colour = NA))

# 6. ANNUAL MEAN TEMPERATURE -------------------------------------------------
p_temp <- ggplot(mean_year, aes(year, t)) +
  geom_smooth(method = "loess", span = 0.5, se = FALSE, colour = hot, linewidth = 1.1, formula = y ~ x) +
  geom_point(colour = warm, size = 1.4) +
  scale_x_continuous(breaks = c(1953, 1970, 1990, 2010, 2025)) +
  scale_y_continuous(labels = \(x) paste0(x, " °C")) +
  labs(title = paste0("About ", round(t_now - t_50s, 1), " °C warmer than in the 1950s"),
       subtitle = "Average temperature of each year (dots) and the long-term trend (line). Most of the rise came after 1990.") +
  theme_minimal(base_family = "lato") +
  theme(plot.title = element_text(family = "serif_t", size = 13, colour = ink, margin = margin(b = 4)),
        plot.subtitle = element_textbox_simple(size = 8.5, colour = muted, lineheight = 1.2, margin = margin(t = 6, b = 8)),
        plot.title.position = "plot",
        axis.title = element_blank(), axis.text = element_text(size = 7.5, colour = faint),
        panel.grid = element_blank(),
        panel.grid.major.y = element_line(colour = "#E4DCD0", linewidth = 0.3),
        plot.background = element_rect(fill = bg, colour = NA))

# 7. WETTEST DAY OF EACH YEAR --------------------------------------------------
top_wet <- wet_year |> slice_max(max, n = 3)
p_rain <- ggplot(wet_year, aes(year, max)) +
  geom_segment(aes(xend = year, y = 0, yend = max), colour = "#A9C3D6", linewidth = 0.5) +
  geom_point(aes(colour = year %in% top_wet$year), size = 1.6) +
  geom_text(data = top_wet, aes(label = paste0(round(max), " mm\n", year)), vjust = -0.35,
            family = "lato", size = 2.6, colour = rain, fontface = "bold", lineheight = 0.9) +
  scale_colour_manual(values = c(`TRUE` = rain, `FALSE` = "#A9C3D6"), guide = "none") +
  scale_x_continuous(breaks = c(1953, 1970, 1990, 2010, 2025)) +
  scale_y_continuous(limits = c(0, 560), breaks = seq(0, 400, 200), labels = \(x) paste0(x, " mm"),
                     expand = c(0, 0)) +
  labs(title = "The wettest day on record came in 2023",
       subtitle = "Rainfall on the wettest day of each year. Total yearly rain shows no trend, but the heaviest days are getting heavier.") +
  theme_minimal(base_family = "lato") +
  theme(plot.title = element_text(family = "serif_t", size = 13, colour = ink, margin = margin(b = 4)),
        plot.subtitle = element_textbox_simple(size = 8.5, colour = muted, lineheight = 1.2, margin = margin(t = 6, b = 8)),
        plot.title.position = "plot",
        axis.title = element_blank(), axis.text = element_text(size = 7.5, colour = faint),
        panel.grid = element_blank(),
        panel.grid.major.y = element_line(colour = "#E4DCD0", linewidth = 0.3),
        plot.background = element_rect(fill = bg, colour = NA))

# 8. BIG NUMBERS -------------------------------------------------------------------
kpi <- tibble(
  x = 0:2,
  big = c(paste0(round(hot_50s), " to ", round(hot_now)), paste0("+", round(t_now - t_50s, 1), " °C"),
          paste0(round(wettest$max), " mm")),
  small = c("very hot days a year,<br>1950s vs 2020–2025",
            "annual mean temperature,<br>1950s vs 2020–2025",
            paste0("the wettest day on record,<br>", format(wettest$day, "%e %B %Y") |> str_squish())),
  col = c(hot, hot, rain)) |>
  mutate(label = paste0("<span style='font-family:serif_t;font-size:28pt;color:", col, "'>", big,
                        "</span><br>", small))
p_kpi <- ggplot(kpi) +
  geom_richtext(aes(x, 1, label = label), hjust = 0, vjust = 1, family = "lato", size = 3.2,
                colour = muted, fill = NA, label.colour = NA, lineheight = 1.15,
                label.padding = unit(0, "pt")) +
  scale_x_continuous(limits = c(0, 3), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, 1), expand = c(0, 0)) +
  coord_cartesian(clip = "off") +
  theme_void()

# 9. LAYOUT ----------------------------------------------------------------------
right <- wrap_elements(full = p_hot / p_temp / p_rain + plot_layout(heights = c(1, 1, 1)) &
                        theme(plot.background = element_rect(fill = bg, colour = NA)))
left  <- wrap_elements(full = p_hero) & theme(plot.background = element_rect(fill = bg, colour = NA))
body  <- left + right + plot_layout(widths = c(1.35, 1))

st <- paste0(
  "Hong Kong is warming, and the change is felt most in summer. In the 1950s the city had about ",
  round(hot_50s), " very hot days a year, mostly in July and August. Since 2020 it has had about ",
  round(hot_now), ", and the hot season now runs from around ", lab_doy(snow$first), " to ",
  lab_doy(snow$last), ". Heavy downpours are setting records too.<br>",
  "<span style='color:", ink, "'>**What is a very hot day?** The Hong Kong Observatory calls a day ",
  "*very hot* when the temperature reaches **33 °C or more**.</span>")

p <- wrap_elements(full = p_kpi) / body + plot_layout(heights = c(0.12, 0.88)) +
  plot_annotation(
    title = "Hong Kong's summers are getting hotter and longer",
    subtitle = st,
    caption = paste0("Very hot day: daily maximum of 33 °C or more, as defined by the Hong Kong Observatory. ",
                     "All data measured at the Hong Kong Observatory headquarters, 1953–2025.<br>",
                     "**Data source:** Hong Kong Observatory, via data.gov.hk · **Creator:** Zoi Diamantakou"),
    theme = theme(
      text = element_text(family = "lato"),
      plot.title = element_text(family = "serif_t", size = 28, colour = ink, margin = margin(b = 10)),
      plot.subtitle = element_textbox_simple(size = 11.5, colour = muted, lineheight = 1.3,
                                             margin = margin(b = 14)),
      plot.caption = element_textbox_simple(size = 8, colour = faint, lineheight = 1.4,
                                            margin = margin(t = 12)),
      plot.background = element_rect(fill = bg, colour = NA),
      plot.margin = margin(36, 36, 30, 36)))
p <- p & theme(plot.background = element_rect(fill = bg, colour = NA))

ggsave("hong_kong.png", p, width = 11.5, height = 10, dpi = 288, bg = bg)
