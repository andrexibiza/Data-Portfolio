library(tidyverse)
library(dplyr)

#Read in Week 7 dataset
df <- readRDS("penguins_clean_w7.rds") 
str(df)

### First, I am making a minor change to the dataset this week.
# Rename "body_mass_g" to "weight"
df$weight <- df$body_mass_g

df$body_mass_g <- NULL

#Sampling Distribution of Sample Means for weight 

set.seed(666) # for reproducibility

mu <- mean(df$weight, na.rm = TRUE) #population mean
sigma <- sd(df$weight, na.rm = TRUE) #population standard deviation

# Number of samples and sample size
msm <- 1000 # number of samples means
nsm <- 30 # sample size means

# Initialize a vector to store the sample means
sample_means <- numeric(msm)

# Loop to draw samples and compute means
for (i in 1:msm) {
  sample <- sample(df$weight, nsm, replace = TRUE)
  sample_means[i] <- mean(sample, na.rm = TRUE)
}

expected_mu_xbar <- mu  #expected mean of sample means
expected_sigma_xbar <- sigma/sqrt(nsm) #expected standard error of sample means

actual_mu_xbar <- mean(sample_means, na.rm = TRUE)  #actual mean of sample means
actual_sigma_xbar <- sd(sample_means, na.rm = TRUE)  #actual standard error of sample means

# Create a dataframe for the sampling distribution
sampling_distribution <- data.frame(sample_means = sample_means)

# Plot the sampling distribution
ggplot(sampling_distribution, aes(x = sample_means)) +
  geom_histogram(aes(y = ..density..), binwidth = 50, color = "black", fill = "blue") +
  geom_density(color = "red", size = 1) +
  ggtitle("Sampling Distribution of Sample Means for Weight (g)") +
  xlab("Sample Mean Weight (g)") +
  ylab("Density")

qqnorm(sample_means, col = "blue")

cat('The population mean weight is:', mu, 'with standard deviation', sigma,'.')
cat('The expected mean of the sample means is:', expected_mu_xbar, 'with standard error', expected_sigma_xbar,'.')
cat('The actual mean of the sample means is:', actual_mu_xbar, 'with standard error', actual_sigma_xbar,'.')


#Sampling Distribution of Sample Proportions for Species Adelie

p <- sum(df$species == "Adelie")/length(df$species) #population proportion success
q <- 1-p #population proportion failure

nsp <- 500 #sample size proportions
msp <- 10000 #number of samples proportions

sample_positions <- c( )
sample_proportions <- c( )


for(i in 1:msp){
  sample_species <- sample(df$species,nsp,replace = TRUE)
  sample_proportions[i] <- sum(sample_species == "Adelie")/length(sample_species)
}

expected_mu_phat <- p #expected mean of sample proportions
expected_sigma_phat <- sqrt(p*q/nsp) #expected standard error of sample proportions

actual_mu_phat <- mean(sample_proportions) #actual mean of sample proportions
actual_sigma_phat <- sd(sample_proportions) #actual standard error of sample proportions

ggplot() + geom_density(aes(sample_proportions),color = "red") +  
  stat_function(fun = dnorm, n = 101, args = list(mean = actual_mu_phat, sd = actual_sigma_phat),color = "blue") +
  ggtitle("Sampling Distribution of Sample Proportion for Species Adelie")

qqnorm(sample_proportions, col = "blue")

cat('The population proportion of species Adelie is:', p, '.')
cat('The expected mean of the sample proportions is:', expected_mu_phat, 'with standard error', expected_sigma_phat,'.')
cat('The actual mean of the sample proportions is:', actual_mu_phat, 'with standard error', actual_sigma_phat,'.')

###################################################################
# Make new Excel and RDS files of Week 7 dataset 
# * "body_mass_g" renamed to "weight" 
###################################################################

write.csv(df, "penguins_clean_w8.csv") #does not preserve structure of variables

write_rds(df, "penguins_clean_w8.rds") #preserves structure of variables


#Check updated Week 8 dataset. 

newdf <- read_rds("penguins_clean_w8.rds")
str(newdf)
