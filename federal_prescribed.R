# set working directory to the folder containing this script
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# required packages
library(tidyverse)
library(janitor)
library(units)
library(scales)
library(jsonlite)
library(httr)
library(patchwork)

# =============================================================================
# Data from federal Integrated Agency Fuels Treatments database
# Analysis run Nov 9, 2026
# =============================================================================

# setup baseline query 
endpoint_url <- "https://services3.arcgis.com/T4QMspbfLg3qTGWY/ArcGIS/rest/services/Integrated_Interagency_Fuels_Treatments_View/FeatureServer/0/query"
page_size <- 2000
offset <- 0
has_more_records <- TRUE

# list to store data chunks
data_chunks <- list()
chunk_index <- 1

# pagination loop
while(has_more_records) {
  
    # build API request 
    response <- GET(
    url = endpoint_url,
    query = list(
      where = "1=1",
      # attribute columns
      outFields = "State,TreatmentName,TreatmentAcres,ActualCompletionDate,TreatmentIdentifierDatabase,TreatmentType,Agency,TreatmentCategory",
      returnGeometry = "false",
      resultRecordCount = page_size,
      resultOffset = offset,
      f = "pjson"
    )
  )
  
  # parse response content
  content_text <- content(response, "text", encoding = "UTF-8")
  parsed_json <- fromJSON(content_text)
  
  # extract data frame
  records <- parsed_json$features$attributes
  
  # check if records returned
  if (!is.null(records) && nrow(records) > 0) {
    data_chunks[[chunk_index]] <- records
    
    # track progress
    message(paste("Fetched records:", offset, "to", offset + nrow(records)))
    
    # move the pointer forward for the next page
    offset <- offset + nrow(records)
    chunk_index <- chunk_index + 1
  } else {
    # if the server returns 0 rows, end loop
    has_more_records <- FALSE
  }
  
  # small pause to avoid server rate-limits
  Sys.sleep(0.1)
}

# combine the data chunks 
fed_treatments <- bind_rows(data_chunks)

# clean up environment
rm(chunk_index,content_text,page_size,endpoint_url,has_more_records,offset,parsed_json,records,response,data_chunks)

# clean data
fed_treatments <- fed_treatments %>%
  clean_names() %>%
  mutate(completion_date = as.POSIXct(actual_completion_date / 1000, origin = "1970-01-01", tz = "UTC"),
         year = year(completion_date)) 

glimpse(fed_treatments) 
# Rows: 502,442
# Columns: 10
# $ state                         <chr> "MT", "CA", "MT", "MT", "UT", "NM", "NM", "UT", "UT", "UT", "UT", "UT", "UT", "UT", "UT", "UT", "UT", "UT…
# $ treatment_name                <chr> "TSMRS LEGACY STAND", "LP FA MASTICATION FY 19", "TSMRS LEGACY STAND", "TSMRS LEGACY STAND", "WEST SLOPE …
# $ treatment_acres               <dbl> 4.0, 56.0, 15.0, 25.0, 18.0, 1248.0, 25.0, 249.0, 373.0, 361.0, 562.0, 528.0, 904.0, 6.0, 6.0, 30.0, 16.0…
# $ actual_completion_date        <dbl> 1.200528e+12, 1.559347e+12, 1.333066e+12, 1.363565e+12, 1.560125e+12, 1.558224e+12, 1.544400e+12, 1.56185…
# $ treatment_identifier_database <chr> "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS…
# $ treatment_type                <chr> "Thinning", "Crushing", "Thinning", "Thinning", "Chipping", "Broadcast Burn", "Machine Pile Burn", "Broad…
# $ agency                        <chr> "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "…
# $ treatment_category            <chr> "Mechanical", "Mechanical", "Mechanical", "Mechanical", "Mechanical", "Fire", "Fire", "Fire", "Fire", "Me…
# $ completion_date               <dttm> 2008-01-17, 2019-06-01, 2012-03-30, 2013-03-18, 2019-06-10, 2019-05-19, 2018-12-10, 2019-06-30, 2019-06-…
# $ year                          <dbl> 2008, 2019, 2012, 2013, 2019, 2019, 2018, 2019, 2019, 2017, 2018, 2020, 2018, 2019, 2019, 2019, 2019, 201…

sort(unique(fed_treatments$agency))
# [1] "BIA"  "BLM"  "BOR"  "FWS"  "NPS"  "USFS"

sort(unique(fed_treatments$treatment_type))
# [1] "Biocontrol"                                "Biological"                               
# [3] "Biomass Removal"                           "Biomass Removall"                         
# [5] "Broadcast"                                 "Broadcast Burn"                           
# [7] "Chemical"                                  "Chemical Treatment"                       
# [9] "Chipping"                                  "Clearcut, Chaining"                       
# [11] "Crushing"                                  "Fire Use"                                 
# [13] "Fuel Compaction"                           "Grazing"                                  
# [15] "Grinding, Chipping, Crushing"              "Hand Pile"                                
# [17] "Hand Pile Burn"                            "Herbicide"                                
# [19] "Herbivory"                                 "Jackpot Burn"                             
# [21] "Lop and Scatter"                           "Machine Pile"                             
# [23] "Machine Pile Burn"                         "Mastication"                              
# [25] "Mastication/Mowing"                        "Mowing"                                   
# [27] "N/A"                                       "Pile"                                     
# [29] "Pile Burn"                                 "Planting"                                 
# [31] "Preparation"                               "Repair recreation facility"               
# [33] "Seeding"                                   "Stabilize/secure/protect critical habitat"
# [35] "Thinning"                                  "Underburn"                                
# [37] "Wildfire" 

sort(unique(fed_treatments$treatment_identifier_database))
# [1] "FACTS"  "IFPRS"  "NFPORS"

sort(unique(fed_treatments$treatment_category))
# [1] "Asset Repair and Replacement" "Biological"                   "Chemical"                    
# [4] "Fire"                         "Invasive Species"             "Mechanical"                  
# [7] "N/A"                          "Other"                        "Planned Ignition"            
# [10] "Preparation for Treatment"    "Reforestation"                "Unplanned Ignition"          
# [13] "Wildfire Non-Treatment"       "Wildlife Habitat"

# filter data for prescribed burns
fed_prescribed <- fed_treatments %>%
  filter(treatment_category == "Fire" | treatment_category == "Planned Ignition") %>%
  mutate(treatment_type = case_when(grepl("Broadcast|Underburn", treatment_type) ~ "Broadcast Burn",
                                        grepl("Pile", treatment_type) ~ "Pile Burn",
                                        TRUE ~ treatment_type)) %>%
  filter(treatment_type!= "Fire Use") # these are wildfires that are allowed to burn, not prescribed burns
  
sort(unique(fed_prescribed$treatment_type))
# [1] "Broadcast Burn" "Jackpot Burn"   "Pile Burn"    

glimpse(fed_prescribed)
# Rows: 123,116
# Columns: 10
# $ state                         <chr> "NM", "NM", "UT", "UT", "CA", "CA", "OR", "MT", "MT", "MT", "CO", "ID", "ID", "UT", "UT", "AR", "AR", "ID…
# $ treatment_name                <chr> "FY19 TIO GORDITO UNIT 6 RX", "FY19 TIO GORDITO PILES RX", "JOHNSON CREEK", "JOHNSON CREEK", "TI BAR 2121…
# $ treatment_acres               <dbl> 1248.0, 25.0, 249.0, 373.0, 14.6, 2.0, 169.0, 24.0, 220.0, 55.0, 12.2, 50.0, 13.0, 125.0, 70.0, 2637.0, 2…
# $ actual_completion_date        <dbl> 1.558224e+12, 1.544400e+12, 1.561853e+12, 1.561853e+12, 1.611014e+12, 1.607645e+12, 1.053734e+12, 1.31734…
# $ treatment_identifier_database <chr> "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS", "FACTS…
# $ treatment_type                <chr> "Broadcast Burn", "Pile Burn", "Broadcast Burn", "Broadcast Burn", "Pile Burn", "Pile Burn", "Jackpot Bur…
# $ agency                        <chr> "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "USFS", "…
# $ treatment_category            <chr> "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "Fire", "…
# $ completion_date               <dttm> 2019-05-19, 2018-12-10, 2019-06-30, 2019-06-30, 2021-01-19, 2020-12-11, 2003-05-24, 2011-09-30, 2008-09-…
# $ year                          <dbl> 2019, 2018, 2019, 2019, 2021, 2020, 2003, 2011, 2008, 2008, 2019, 2018, 2009, 2012, 2016, 2020, 2021, 200…

# =============================================================================
# Annual summaries, from 2015
# =============================================================================

# federal prescribed burns by year 
fed_prescribed_year <- fed_prescribed %>%
  filter(year >= 2015) %>%
  group_by(year) %>%
  summarize(treatments = n(),
            acres = sum(treatment_acres, na.rm = TRUE))

# federal prescribed burns by year and type
fed_prescribed_type_year <- fed_prescribed %>%
  filter(year >= 2015) %>%
  group_by(treatment_type,year) %>%
  summarize(treatments = n(),
            acres = sum(treatment_acres, na.rm = TRUE))

# federal prescribed burns by year, type and agency
fed_prescribed_agency_type_year <- fed_prescribed %>%
  filter(year >= 2015) %>%
  group_by(agency,treatment_type,year) %>%
  summarize(treatments = n(),
            acres = sum(treatment_acres, na.rm = TRUE))

# =============================================================================
# Charts
# =============================================================================

# federal prescribed burns by year 
p1 <- ggplot(fed_prescribed_year, aes(x = year, y = treatments)) + 
  geom_col(fill = "red", color = NA, linewidth = 0.1) + 
  geom_hline(yintercept = 0, linewidth = 0.3) +
  scale_x_continuous(breaks = c(2015,2017,2019,2021,2023,2025)) +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +labs(title = "Number of Prescribed Burns") +
  xlab("") +
  ylab("")

p2 <- ggplot(fed_prescribed_year, aes(x = year, y = acres)) + 
  geom_col(fill = "red", color = NA, linewidth = 0.1) + 
  geom_hline(yintercept = 0, linewidth = 0.3) +
  scale_x_continuous(breaks = c(2015,2017,2019,2021,2023,2025)) +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +labs(title = "Acres Treated With Prescribed Burns") +
  xlab("") +
  ylab("")

p1 / p2

# federal prescribed burns by year and type
p1 <- ggplot(fed_prescribed_type_year, aes(x = year, y = treatments)) + 
  geom_col(fill = "red", color = NA, linewidth = 0.1) + 
  geom_hline(yintercept = 0, linewidth = 0.3) +
  facet_wrap(~treatment_type) +
  scale_x_continuous(breaks = c(2015,2017,2019,2021,2023,2025)) +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +labs(title = "Number of Prescribed Burns") +
  xlab("") +
  ylab("")


p2 <- ggplot(fed_prescribed_type_year, aes(x = year, y = acres)) + 
  geom_col(fill = "red", color = NA, linewidth = 0.1) + 
  geom_hline(yintercept = 0, linewidth = 0.3) +
  facet_wrap(~treatment_type) +
  scale_x_continuous(breaks = c(2015,2017,2019,2021,2023,2025)) +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +labs(title = "Acres Treated With Prescribed Burns") +
  xlab("") +
  ylab("")

p1 / p2

# federal prescribed burns by year, type and agency

p1 <- ggplot(fed_prescribed_agency_type_year, aes(x = year, y = treatments)) + 
  geom_col(fill = "red", color = NA, linewidth = 0.1) + 
  geom_hline(yintercept = 0, linewidth = 0.3) +
  facet_grid(vars(agency),vars(treatment_type), scales="free_y") +
  scale_x_continuous(breaks = c(2015,2017,2019,2021,2023,2025)) +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +labs(title = "Number of Prescribed Burns") +
  xlab("") +
  ylab("")

p2 <- ggplot(fed_prescribed_agency_type_year, aes(x = year, y = acres)) + 
  geom_col(fill = "red", color = NA, linewidth = 0.1) + 
  geom_hline(yintercept = 0, linewidth = 0.3) +
  facet_grid(vars(agency),vars(treatment_type), scales="free_y") +
  scale_x_continuous(breaks = c(2015,2017,2019,2021,2023,2025)) +
  scale_y_continuous(labels = comma) +
  theme_minimal() +
  theme(panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +labs(title = "Acres Treated With Prescribed Burns") +
  xlab("") +
  ylab("")

p1 / p2

# remove charts from environment 
rm(p1,p2)

# change in number of USFS pile burns from 2020-22 to 2023-25
fed_prescribed_agency_type_year %>%
  filter(agency == "USFS" & treatment_type == "Pile Burn" & year >= 2020 & year <= 2022) %>%
  pull(treatments) %>%
  mean()
# [1] 2564.667

fed_prescribed_agency_type_year %>%
  filter(agency == "USFS" & treatment_type == "Pile Burn" & year >= 2023 & year <= 2025) %>%
  pull(treatments) %>%
  mean()
# [1] 5098

5098/2564.667
# [1] 1.987782
# As noted, the number of pile burns conducted by the U.S. Forest Service almost doubled 
#after the Hermit’s Peak/Calf Canyon incident, a comparison of the years 2023 to 2025 to the prior three years shows

