### DATA5350 Project 3 - NASA Geospatial Metadata
### Axl Ibiza, MBA
### 2024-10-08

# Code adapted from https://www.tidytextmining.com/nasa

# Load packages
library(dplyr)
library(ggraph)
library(ggplot2)
library(igraph)
library(jsonlite)
library(tidyr)
library(tidytext)
library(topicmodels)
library(widyr)

# Import JSON metadata from NASA
metadata <- fromJSON("https://data.nasa.gov/data.json")
names(metadata$dataset)

### Data Cleaning
# Titles
nasa_title <- tibble(id = metadata$dataset$identifier, 
                     title = metadata$dataset$title)
nasa_title

# Descriptions
nasa_desc <- tibble(id = metadata$dataset$identifier, 
                    desc = metadata$dataset$description)

nasa_desc %>% 
  select(desc) %>% 
  sample_n(5)

# Keywords
nasa_keyword <- tibble(id = metadata$dataset$identifier, 
                       keyword = metadata$dataset$keyword) %>%
  unnest(keyword)

nasa_keyword

### Text Pre-processing for Titles and Descriptions
nasa_title <- nasa_title %>% 
  unnest_tokens(word, title) %>% 
  anti_join(stop_words)

nasa_desc <- nasa_desc %>% 
  unnest_tokens(word, desc) %>% 
  anti_join(stop_words)

nasa_title
nasa_desc

### Initial Simple Exploration
nasa_title %>%
  count(word, sort = TRUE)

nasa_desc %>% 
  count(word, sort = TRUE)

# Need a custom stopword list
my_stopwords <- tibble(word = c(as.character(1:10), 
                                "v1.0", "v03", "l2", "l3", "l4", "v5.2.0", 
                                "v003", "v004", "v005", "v006", "v7"))
nasa_title <- nasa_title %>% 
  anti_join(my_stopwords)
nasa_desc <- nasa_desc %>% 
  anti_join(my_stopwords)

# What are the most common keywords?
nasa_keyword %>% 
  group_by(keyword) %>% 
  count(sort = TRUE)

# Change all keywords to uppercase
nasa_keyword <- nasa_keyword %>% 
  mutate(keyword = toupper(keyword))

### Word Co-occurrences and Correlations
# Titles
title_word_pairs <- nasa_title %>% 
  pairwise_count(word, id, sort = TRUE, upper = FALSE)

title_word_pairs

# Descriptions
desc_word_pairs <- nasa_desc %>% 
  pairwise_count(word, id, sort = TRUE, upper = FALSE)

desc_word_pairs

# Visualize title word pairs
set.seed(1234)
title_word_pairs %>%
  filter(n >= 250) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(edge_alpha = n, edge_width = n), edge_colour = "cyan4") +
  geom_node_point(size = 5) +
  geom_node_text(aes(label = name), repel = TRUE, 
                 point.padding = unit(0.2, "lines")) +
  theme_void()

# Visualize description word pairs
desc_word_pairs %>%
  filter(n >= 2000) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(edge_alpha = n, edge_width = n), edge_colour = "darkred") +
  geom_node_point(size = 5) +
  geom_node_text(aes(label = name), repel = TRUE,
                 point.padding = unit(0.2, "lines")) +
  theme_void()

# Keyword networks
keyword_pairs <- nasa_keyword %>% 
  pairwise_count(keyword, id, sort = TRUE, upper = FALSE)

keyword_pairs %>%
  filter(n >= 700) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(edge_alpha = n, edge_width = n), edge_colour = "royalblue") +
  geom_node_point(size = 5) +
  geom_node_text(aes(label = name), repel = TRUE,
                 point.padding = unit(0.2, "lines")) +
  theme_void()

# Keyword correlations
keyword_cors <- nasa_keyword %>% 
  group_by(keyword) %>%
  filter(n() >= 50) %>%
  pairwise_cor(keyword, id, sort = TRUE, upper = FALSE)

keyword_cors

# Visualize keyword correlations
keyword_cors %>%
  filter(correlation > .8) %>%
  graph_from_data_frame() %>%
  ggraph(layout = "fr") +
  geom_edge_link(aes(edge_alpha = correlation, edge_width = correlation), edge_colour = "royalblue") +
  geom_node_point(size = 5) +
  geom_node_text(aes(label = name), repel = TRUE,
                 point.padding = unit(0.2, "lines")) +
  theme_void()

### Calculating TF-IDF for descriptions
desc_tf_idf <- nasa_desc %>% 
  count(id, word, sort = TRUE) %>%
  bind_tf_idf(word, id, n)

# Highest TF-IDF words
desc_tf_idf %>% 
  arrange(-tf_idf)

desc_tf_idf <- full_join(desc_tf_idf, nasa_keyword, by = "id")

desc_tf_idf %>% 
  filter(!near(tf, 1)) %>%
  filter(keyword %in% c("EARTH SCIENCE", "ATMOSPHERE", 
                        "SEISMOLOGY", "CLIMATE",
                        "GEOGRAPHY", "ATMOSPHERIC SCIENCE")) %>%
  arrange(desc(tf_idf)) %>%
  group_by(keyword) %>%
  distinct(word, keyword, .keep_all = TRUE) %>%
  slice_max(tf_idf, n = 15, with_ties = FALSE) %>% 
  ungroup() %>%
  mutate(word = factor(word, levels = rev(unique(word)))) %>%
  ggplot(aes(tf_idf, word, fill = keyword)) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~keyword, ncol = 3, scales = "free") +
  labs(title = "Highest tf-idf words in NASA metadata description fields",
       caption = "NASA metadata from https://data.nasa.gov/data.json",
       x = "tf-idf", y = NULL)

### Topic Modeling

# Casting to a Document-Term Matrix
my_stop_words <- bind_rows(stop_words, 
                           tibble(word = c("nbsp", "amp", "gt", "lt",
                                           "timesnewromanpsmt", "font",
                                           "td", "li", "br", "tr", "quot",
                                           "st", "img", "src", "strong",
                                           "http", "file", "files",
                                           as.character(1:12)), 
                                  lexicon = rep("custom", 30)))

word_counts <- nasa_desc %>%
  anti_join(my_stop_words) %>%
  count(id, word, sort = TRUE) %>%
  ungroup()

word_counts

desc_dtm <- word_counts %>%
  cast_dtm(id, word, n)

desc_dtm

# ready for topic modeling
# be aware that running this model is time intensive
desc_lda <- LDA(desc_dtm, k = 12, control = list(seed = 1234))
desc_lda

# tidy the models
tidy_lda_12 <- tidy(desc_lda)
tidy_lda_12

tidy_lda_24 <- tidy(desc_lda_24)
tidy_lda_24

# Top terms for each topic
top_terms <- tidy_lda_12 %>%
  group_by(topic) %>%
  slice_max(beta, n = 10, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(topic, -beta)

top_terms

# Visualize top terms by topic
top_terms %>%
  mutate(term = reorder_within(term, beta, topic)) %>%
  group_by(topic, term) %>%    
  arrange(desc(beta)) %>%  
  ungroup() %>%
  ggplot(aes(beta, term, fill = as.factor(topic))) +
  geom_col(show.legend = FALSE) +
  scale_y_reordered() +
  labs(title = "Top 10 terms in each LDA topic",
       x = expression(beta), y = NULL) +
  facet_wrap(~ topic, ncol = 4, scales = "free")

# Examine probability that a document belongs in each topic
lda_gamma <- tidy(desc_lda, matrix = "gamma")

lda_gamma

# Distribution of probabilities for all topics
ggplot(lda_gamma, aes(gamma)) +
  geom_histogram(alpha = 0.8) +
  scale_y_log10() +
  labs(title = "Distribution of probabilities for all topics",
       y = "Number of documents", x = expression(gamma))

# Distribution of probability for each topic
ggplot(lda_gamma, aes(gamma, fill = as.factor(topic))) +
  geom_histogram(alpha = 0.8, show.legend = FALSE) +
  facet_wrap(~ topic, ncol = 4) +
  scale_y_log10() +
  labs(title = "Distribution of probability for each topic",
       y = "Number of documents", x = expression(gamma))

# Connecting topic models with keywords
lda_gamma <- full_join(lda_gamma, nasa_keyword, by = c("document" = "id"))

lda_gamma

# Top keywords
top_keywords <- lda_gamma %>% 
  filter(gamma > 0.9) %>% 
  count(topic, keyword, sort = TRUE)

top_keywords

# Top keywords for each topic
top_keywords %>%
  group_by(topic) %>%
  slice_max(n, n = 5, with_ties = FALSE) %>%
  ungroup %>%
  mutate(keyword = reorder_within(keyword, n, topic)) %>%
  ggplot(aes(n, keyword, fill = as.factor(topic))) +
  geom_col(show.legend = FALSE) +
  labs(title = "Top keywords for each LDA topic",
       x = "Number of documents", y = NULL) +
  scale_y_reordered() +
  facet_wrap(~ topic, ncol = 2, scales = "free")