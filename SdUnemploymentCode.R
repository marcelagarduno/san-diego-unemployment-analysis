## Building data sets
cal_dat <- read_csv("laborforceandunemployment_monthly_2025919.csv")
sandiego_dat <- cal_dat|>
  filter(`Area Name` == "San Diego County")

glimpse(sandiego_dat)

# Skim Tables
skim(sandiego_dat)

# Histogram of our unemployment rate
ggplot(data = sandiego_dat, aes(x = `Unemployment Rate`)) + 
  geom_histogram(color = 'white', bins = 25) +
  labs(x = 'Unemployment Rate', y = 'Count', 
       title = 'Distribution of Unemployment rate')

# Creating a boxplot of Unemployment using month/year as x-variable
ggplot(data = sandiego_dat, aes(x = factor(Month), y = `Unemployment Rate`)) + 
  geom_boxplot() + 
  labs(x = "Month", y = "Unemployment rate", 
       title = "Boxplot of Unemployment by Month")

# Unemployment by decade
sandiego_maybe <- sandiego_dat|>
  mutate(Decade = floor(sandiego_dat$Year/10) * 10)

ggplot(data = sandiego_maybe, aes(x = factor(Decade), y = `Unemployment Rate`)) + 
  geom_boxplot() + 
  labs(x = "Decade", y = "Unemployment rate", 
       title = "Boxplot of Unemployment by Decade (1990-2025)")


### Seasonal Patterns in San Diego (ANOVA test)
sandiego_dat <- sandiego_dat|>
  separate(Date_Numeric, into = c('NumMonth','Year2'), sep ='/')

sandiego_dat$NumMonth <- as.integer(sandiego_dat$NumMonth)

sandiego_dat <- sandiego_dat|>
  select(-Year2 )

sandiego_dat <- sandiego_dat |>
  mutate(Season = cut(NumMonth, breaks = c(0, 3, 6, 9, 12),
                      labels = c("Winter", "Spring", "Summer", "Fall"),
                      right = FALSE),
         Season=ifelse(NumMonth == 12, "Winter", as.character(Season)),
         Season=factor(Season, levels=c("Winter", "Spring", "Summer", "Fall"))) 


# Boxplot of Unemployment Rate by Season
ggplot(sandiego_dat, aes(x = Season, y = `Unemployment Rate`)) +
  geom_boxplot() + # Shows distribution
  stat_summary(fun = mean, geom = "point", shape = 5) + 
  labs(title = "Boxplot of Unemployment by Season with Mean", x = "Season", 
       y = "Unemployment Rate")

# ANOVA Test to see if there's a difference of the means in at least one seasons
unemply_season_lm <- lm(`Unemployment Rate` ~ Season, sandiego_dat)
anova(unemply_season_lm)

get_regression_table(unemply_season_lm)


### Predicting San Diego Unemployment Rate using Year
# Plot the raw data
ggplot(sandiego_dat,
       mapping = aes(x = Year, y = `Unemployment Rate`, color = Season)) +
  geom_point() +
  labs(x = "Year", y = "Umemployment Rate (%)", color = "Season", 
       title = "Unemployment Over the Years within Seasons") +
  theme()+
  geom_smooth(method = "loess", formula = y ~ x, se = FALSE)

# Obtain the largest unemployment rate
sandiego_dat |>
  slice_max(`Unemployment Rate`)
# 15.8% in Spring 2020

# Create a linear regression model without removing outliers
outlier_mod <- lm(`Unemployment Rate` ~ Year , data = sandiego_dat)
get_regression_table(outlier_mod) |>
  select(term, estimate, p_value,everything())

# Correlation before removing outliers
sandiego_dat|>
  summarise(correlation = cor(`Unemployment Rate`, Year))
# Correlation after removing outliers
sandiego_dat |>
  filter(!((Year == 2020 | Year == 2021) & (`Unemployment Rate` > 6))) |>
  summarise(correlation = cor(`Unemployment Rate`, Year))

# Subset without outliers
sd_no2020_2021 <- sandiego_dat |>
  filter(!((Year == 2020 | Year == 2021) & (`Unemployment Rate` > 6)))

# Plot unemployment rates without outliers 
ggplot(sd_no2020_2021,
       mapping = aes(x = Year, y = `Unemployment Rate`, color = Season)) +
  geom_point() +
  labs(x = "Year", y = "Umemployment Rate (%)", color = "Season", 
       title = "Unemployment Over the Years within Seasons") +
  theme()+
  geom_smooth(method = "loess", formula = y ~ x, se = FALSE)

# Create a linear regression model with removed outliers
no_outlier_mod <- lm(`Unemployment Rate` ~ Year , data = sd_no2020_2021)
get_regression_table(no_outlier_mod) |>
  select(term, estimate, p_value,everything())



### San Diego Unemployment Before versus After the Pandemic

# Create pre(2015–2019) / post(2020–2024) variable, excluding other years
sandiego_bootstrap <- sandiego_dat |>
  mutate(period = ifelse(Year >= 2015 & Year <= 2019, "pre", 
                         ifelse(Year >= 2020 & Year <= 2024, "post", NA))) |>
  filter(period %in% c("pre", "post"))

# Observed difference in average unemployment rates pre- and post- pandemic
obs_diff_means <- sandiego_bootstrap |>
  specify(response = `Unemployment Rate`, explanatory = period) |>
  calculate(stat = "diff in means", order = c("post", "pre"))
obs_diff_means

# Generate a sampling distribution (1,000 resamples) for the mean difference
set.seed(1)
boot_diff_means <- sandiego_bootstrap |>
  specify(response = `Unemployment Rate`, explanatory = period) |>
  hypothesize(null = "independence") |>
  generate(reps = 1000, type = "bootstrap") |>
  calculate(stat = "diff in means", order = c("post", "pre"))

# Calculate the 95% percentile bootstrap confidence interval
percentile_ci_means <- boot_diff_means |>
  get_confidence_interval(type = "percentile", level = 0.95)
percentile_ci_means

visualize(boot_diff_means) +
  shade_confidence_interval(endpoints = percentile_ci_means) +
  labs(title = 'Bootstrap Distribution of Difference in Means', 
       x = 'Difference in Means')

# Calculate the overall mean unemployment rate and factorize high_unemp
avg_rate <- mean(sandiego_bootstrap$`Unemployment Rate`)
sandiego_bootstrap <- sandiego_bootstrap |>
  mutate(high_unemp = factor(ifelse(`Unemployment Rate` > avg_rate, 
                                    "High", "Low")))

# Calculate the observed difference in high-unemployment proportions between pre/post
obs_diff_in_props <- sandiego_bootstrap |>
  specify(response = high_unemp, explanatory = period, success = "High") |>
  calculate(stat = "diff in props", order = c("post", "pre"))
obs_diff_in_props

# Create a bootstrap distribution of the proportion difference (1000 resamples)
set.seed(1)
boot_diff_prop <- sandiego_bootstrap |>
  specify(response = high_unemp, explanatory = period, success = "High") |>
  hypothesize(null = "independence") |>
  generate(reps = 1000, type = "bootstrap") |>
  calculate(stat = "diff in props", order = c("post", "pre"))

# Calculate the 95% bootstrap percentile CI for the difference in proportions
percentile_ci_props <- boot_diff_prop |>
  get_confidence_interval(type = "percentile", level = 0.95)
percentile_ci_props

visualize(boot_diff_prop) +
  shade_confidence_interval(endpoints = percentile_ci_props) +
  labs(title = 'Bootstrap Distribution of Difference in Proportions', 
       x = 'Difference in Proportions')

