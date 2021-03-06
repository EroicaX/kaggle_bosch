# Libraries

my_script_is_using <- "E:/"
my_script_subbed <- basename(my_script_is_using)
threads <- 12

library(data.table)
library(Matrix)
library(recommenderlab)
library(Laurae)
library(fastdigest)
library(pbapply)
library(ggplot2)
library(R.utils)
library(stringi)
library(xgboost)
library(feather)
library(h2o)
localH2O = h2o.init(nthreads = threads, max_mem_size = "48G")

setwd("E:/")

label <- readRDS("datasets/labels.rds")

StratifiedCV <- function(Y, folds, seed) {
  folded <- list()
  folded1 <- list()
  folded2 <- list()
  set.seed(seed)
  temp_Y0 <- which(Y == 0)
  temp_Y1 <- which(Y == 1)
  for (i in 1:folds) {
    folded1[[i]] <- sample(temp_Y0, floor(length(temp_Y0) / ((folds + 1) - i)))
    temp_Y0 <- temp_Y0[!temp_Y0 %in% folded1[[i]]]
    folded2[[i]] <- sample(temp_Y1, floor(length(temp_Y1) / ((folds + 1) - i)))
    temp_Y1 <- temp_Y1[!temp_Y1 %in% folded2[[i]]]
    folded[[i]] <- c(folded1[[i]], folded2[[i]])
  }
  return(folded)
}

folds <- StratifiedCV(label, 5, 11111)

mcc_eval_print <- function(y_prob, y_true) {
  y_true <- y_true
  
  DT <- data.table(y_true = y_true, y_prob = y_prob, key = "y_prob")
  cleaner <- !duplicated(DT[, "y_prob"], fromLast = TRUE)
  
  nump <- sum(y_true)
  numn <- length(y_true) - nump
  
  DT[, tn_v := as.numeric(cumsum(y_true == 0))]
  DT[, fp_v := cumsum(y_true == 1)]
  DT[, fn_v := numn - tn_v]
  DT[, tp_v := nump - fp_v]
  DT <- DT[cleaner, ]
  DT[, mcc_v := (tp_v * tn_v - fp_v * fn_v) / sqrt((tp_v + fp_v) * (tp_v + fn_v) * (tn_v + fp_v) * (tn_v + fn_v))]
  DT[, mcc_v := ifelse(!is.finite(mcc_v), 0, mcc_v)]
  gc(verbose = FALSE)
  
  return(max(DT[['mcc_v']]))
  
}

mcc_eval_pred <- function(y_prob, y_true) {
  y_true <- y_true
  
  DT <- data.table(y_true = y_true, y_prob = y_prob, key = "y_prob")
  cleaner <- !duplicated(DT[, "y_prob"], fromLast = TRUE)
  
  nump <- sum(y_true)
  numn <- length(y_true) - nump
  
  DT[, tn_v := as.numeric(cumsum(y_true == 0))]
  DT[, fp_v := cumsum(y_true == 1)]
  DT[, fn_v := numn - tn_v]
  DT[, tp_v := nump - fp_v]
  DT <- DT[cleaner, ]
  DT[, mcc_v := (tp_v * tn_v - fp_v * fn_v) / sqrt((tp_v + fp_v) * (tp_v + fn_v) * (tn_v + fp_v) * (tn_v + fn_v))]
  DT[, mcc_v := ifelse(!is.finite(mcc_v), 0, mcc_v)]
  
  return(DT[['y_prob']][which.max(DT[['mcc_v']])])
  
}

mcc_eval_nofail_fold <- function(pred, dtrain) {
  
  j <<- j + 1
  
  if (((j %% 2) == 1) | (j < 20)) {
    
    return(list(metric = "mcc", value = 0))
    
  } else {
    
    y_true <- getinfo(dtrain, "label")
    
    DT <- data.table(y_true = y_true, y_prob = pred, key = "y_prob")
    cleaner <- !duplicated(DT[, "y_prob"], fromLast = TRUE)
    nump <- sum(y_true)
    numn <- length(y_true) - nump
    
    DT[, tn_v := cumsum(y_true == 0)]
    DT[, fp_v := cumsum(y_true == 1)]
    DT[, fn_v := numn - tn_v]
    DT[, tp_v := nump - fp_v]
    DT <- DT[cleaner, ]
    DT[, mcc_v := (tp_v * tn_v - fp_v * fn_v) / sqrt((tp_v + fp_v) * (tp_v + fn_v) * (tn_v + fp_v) * (tn_v + fn_v))]
    DT[, mcc_v := ifelse(!is.finite(mcc_v), 0, mcc_v)]
    
    if ((j %% 50) == 0) {gc(verbose = FALSE)}
    
    return(list(metric = "mcc", value = round(max(DT[['mcc_v']]), digits = 12)))
    
  }
  
}

train <- read_feather("Shubin/retrain_material/train.feather")
test <- read_feather("Shubin/retrain_material/test.feather")
train[, "xgb_jay_joost_v2"] <- fread("Laurae/20161110_xgb_jayjoost_fix2/aaa_stacker_preds_train_headerY_scale.csv")$x
test[, "xgb_jay_joost_v2"] <- fread("Laurae/20161110_xgb_jayjoost_fix2/aaa_stacker_preds_test_headerY_scale.csv")$x
train[, "gbm_jay_joost_v2"] <- fread("Laurae/20161111_lgbm_jayjoost/aaa_stacker_preds_train_headerY_scale.csv")$x
test[, "gbm_jay_joost_v2"] <- fread("Laurae/20161111_lgbm_jayjoost/aaa_stacker_preds_test_headerY_scale.csv")$x
train[, "gbm_jay"] <- fread("Laurae/20161111_lgbm_jay/aaa_stacker_preds_train_headerY_scale.csv")$x
test[, "gbm_jay"] <- fread("Laurae/20161111_lgbm_jay/aaa_stacker_preds_test_headerY_scale.csv")$x
train[, "gbm_mike"] <- fread("Laurae/20161110_lgbm_mike/aaa_stacker_preds_train_headerY_scale.csv")$x
test[, "gbm_mike"] <- fread("Laurae/20161110_lgbm_mike/aaa_stacker_preds_test_headerY_scale.csv")$x
train[, "xgb_mike"] <- fread("Laurae/20161110_xgb_mike/aaa_stacker_preds_train_headerY_scale.csv")$x
test[, "xgb_mike"] <- fread("Laurae/20161110_xgb_mike/aaa_stacker_preds_test_headerY_scale.csv")$x
# train <- train[, c(2, 4, 9, 11, 25:30, 138:139)]
# test <- test[, c(2, 4, 9, 11, 25:30, 138:139)]
#train <- train[, c(2, 4, 9, 11, 25:132, 138:139)]
#test <- test[, c(2, 4, 9, 11, 25:132, 138:139)]

for (i in 1:length(folds)) {
  fwrite(cbind(train[-folds[[i]], ], Response = label[-folds[[i]]]), file.path(my_script_is_using, paste0("train_", i, ".csv")), verbose = TRUE)
  fwrite(cbind(train[folds[[i]], ], Response = label[folds[[i]]]), file.path(my_script_is_using, paste0("val_", i, ".csv")), verbose = TRUE)
}
fwrite(cbind(train, Response = label), file.path(my_script_is_using, "train.csv"), verbose = TRUE)
fwrite(test, file.path(my_script_is_using, "test.csv"), verbose = TRUE)

my_train <- list()
my_test <- list()
for (i in 1:length(folds)) {
  my_train[[i]] <- h2o.importFile(file.path(my_script_is_using, paste0("train_", i, ".csv")))
  my_train[[i]]$Response <- as.factor(my_train[[i]]$Response)
  my_test[[i]] <- h2o.importFile(file.path(my_script_is_using, paste0("val_", i, ".csv")))
  my_test[[i]]$Response <- as.factor(my_test[[i]]$Response)
}
my_train_all <- h2o.importFile(file.path(my_script_is_using, "train.csv"))
my_train_all$Response <- as.factor(my_train_all$Response)
my_test_all <- h2o.importFile(file.path(my_script_is_using, "test.csv"))


predictions1 <- numeric(1183747)
predictions2 <- numeric(1183748)
predictions3 <- data.frame(matrix(rep(0, 1183748*length(folds)), nrow = 1183748))

sink(file = file.path(my_script_is_using, "logs_ex.txt"), append = TRUE, split = TRUE)
cat("Starting modeling... on ", format(Sys.time(), "%a %b %d %Y %X"), "\n\n\n", sep = "")
sink()

for (i in 1:length(folds)) {
  
  temp_model <- h2o.randomForest(x = 1:12,
                                 y = "Response",
                                 training_frame = my_train[[i]],
                                 ntrees = 200,
                                 max_depth = 12,
                                 min_rows = 20,
                                 seed = 11111)
  
  sink(file = file.path(my_script_is_using, "logs_ex.txt"), append = TRUE, split = TRUE)
  cat("\nTime: ", format(Sys.time(), "%a %b %d %Y %X"), sep = "")
  predictions1[folds[[i]]] <- as.data.frame(h2o.predict(temp_model, my_test[[i]]))$p1
  predictions3[, i] <- as.data.frame(h2o.predict(temp_model, my_test_all))$p1
  predictions2 <- predictions3[, i] + predictions2
  temp_mcc <- mcc_eval_pred(y_prob = predictions1[folds[[i]]], y_true = label[folds[[i]]])
  temp_preds <- as.numeric(predictions1[folds[[i]]] > temp_mcc)
  cat("\nConfusion matrix:\n")
  print(table(data.frame(preds = temp_preds, truth = label[folds[[i]]])))
  print(table(data.frame(preds = temp_preds, truth = label[folds[[i]]]))/length(folds[[i]]))
  cat("Fold ", i, ": MCC=", mcc_eval_print(y_prob = predictions1[folds[[i]]], y_true = label[folds[[i]]]), "\n", sep = "")
  sink()
  write.csv(predictions1, file = file.path(my_script_is_using, "predictions_oof.csv"), row.names = FALSE)
  write.csv(predictions3, file = file.path(my_script_is_using, "predictions_test_raw.csv"), row.names = FALSE)
  
}

predictions2 <- predictions2 / length(folds)
write.csv(predictions1, file = file.path(my_script_is_using, "predictions_oof.csv"), row.names = FALSE)
write.csv(predictions2, file = file.path(my_script_is_using, "predictions_test_mean.csv"), row.names = FALSE)


gc()
temp_model <- h2o.randomForest(x = 1:12,
                               y = "Response",
                               training_frame = my_train_all,
                               ntrees = 200,
                               max_depth = 12,
                               min_rows = 20,
                               seed = 11111)

validationValues <- predictions1
predictedValuesCV <- predictions2
predictedValuesCVList <- predictions3
predictedValues <- as.data.frame(h2o.predict(temp_model, my_test_all))$p1









mcc_fixed <- function(y_prob, y_true, prob) {
  
  positives <- as.logical(y_true) # label to boolean
  counter <- sum(positives) # get the amount of positive labels
  tp <- as.numeric(sum(y_prob[positives] > prob))
  fp <- as.numeric(sum(y_prob[!positives] > prob))
  tn <- as.numeric(length(y_true) - counter - fp) # avoid computing he opposite
  fn <- as.numeric(counter - tp) # avoid computing the opposite
  mcc <- (tp * tn - fp * fn) / (sqrt((tp + fp) * (tp + fn) * (tn + fp) * (tn + fn)))
  mcc <- ifelse(is.na(mcc), -1, mcc)
  return(mcc)
  
}

mcc_eval_print <- function(y_prob, y_true) {
  y_true <- y_true
  
  DT <- data.table(y_true = y_true, y_prob = y_prob, key = "y_prob")
  cleaner <- !duplicated(DT[, "y_prob"], fromLast = TRUE)
  
  nump <- sum(y_true)
  numn <- length(y_true) - nump
  
  DT[, tn_v := as.numeric(cumsum(y_true == 0))]
  DT[, fp_v := cumsum(y_true == 1)]
  DT[, fn_v := numn - tn_v]
  DT[, tp_v := nump - fp_v]
  DT <- DT[cleaner, ]
  DT[, mcc_v := (tp_v * tn_v - fp_v * fn_v) / sqrt((tp_v + fp_v) * (tp_v + fn_v) * (tn_v + fp_v) * (tn_v + fn_v))]
  DT[, mcc_v := ifelse(!is.finite(mcc_v), 0, mcc_v)]
  gc(verbose = FALSE)
  
  return(max(DT[['mcc_v']]))
  
}

mcc_eval_pred <- function(y_prob, y_true) {
  y_true <- y_true
  
  DT <- data.table(y_true = y_true, y_prob = y_prob, key = "y_prob")
  cleaner <- !duplicated(DT[, "y_prob"], fromLast = TRUE)
  
  nump <- sum(y_true)
  numn <- length(y_true) - nump
  
  DT[, tn_v := as.numeric(cumsum(y_true == 0))]
  DT[, fp_v := cumsum(y_true == 1)]
  DT[, fn_v := numn - tn_v]
  DT[, tp_v := nump - fp_v]
  DT <- DT[cleaner, ]
  DT[, mcc_v := (tp_v * tn_v - fp_v * fn_v) / sqrt((tp_v + fp_v) * (tp_v + fn_v) * (tn_v + fp_v) * (tn_v + fn_v))]
  DT[, mcc_v := ifelse(!is.finite(mcc_v), 0, mcc_v)]
  
  return(DT[['y_prob']][which.max(DT[['mcc_v']])])
  
}

FastROC <- function(y, x) {
  
  # y = actual
  # x = predicted
  x1 = as.numeric(x[y == 1])
  n1 = as.numeric(length(x1))
  x2 = as.numeric(x[y == 0])
  n2 = as.numeric(length(x2))
  r = rank(c(x1,x2))
  return((sum(r[1:n1]) - n1 * (n1 + 1) / 2) / (n1 * n2))
  
}


# Know what is inside

AnalysisFunc <- function(label, folds, validationValues, predictedValuesCV, predictedValues, manual = NA) {
  # Label = your label
  # Folds = your fold list
  # validationValues = your validation values (out of fold predictions)
  # predictedValuesCV = your predicted values (on test data) from CV (set as "NA" if you don't have any)
  # predictedValues = your prediction values (on test data) on a model trained on all data (set as "NA" if you don't have any)
  
  
  # Setup tee
  sink(file = file.path(my_script_is_using, "diagnostics.txt"), append = FALSE, split = TRUE)
  cat("```r\n")
  
  # Get AUC metric information
  temp_auc <- numeric(length(folds))
  best_auc <- 0
  for (j in 1:length(folds)) {
    temp_auc[j] <- FastROC(y = label[folds[[j]]], x = validationValues[folds[[j]]])
    best_auc <- best_auc + (temp_auc[j] / length(folds))
    cat("Fold ", j, ": AUC=", sprintf("%.07f", temp_auc[j]), "\n", sep = "")
  }
  cat("AUC: ", sprintf("%.07f", mean(temp_auc)), " + ", sprintf("%.07f", sd(temp_auc)), "\n", sep = "")
  cat("Average AUC using all data: ", sprintf("%.07f", FastROC(y = label, x = validationValues)), "\n\n\n", sep = "")
  
  
  # Get MCC metric information
  temp_mcc <- numeric(length(folds))
  temp_thresh <- numeric(length(folds))
  temp_positives <- numeric(length(folds))
  temp_detection <- numeric(length(folds))
  temp_true <- numeric(length(folds))
  temp_undetect <- numeric(length(folds))
  best_mcc <- 0
  for (j in 1:length(folds)) {
    
    temp_mcc[j] <- mcc_eval_print(y_prob = validationValues[folds[[j]]], y_true = label[folds[[j]]])
    temp_thresh[j] <- mcc_eval_pred(y_prob = validationValues[folds[[j]]], y_true = label[folds[[j]]])
    mini_preds <- validationValues[folds[[j]]] > temp_thresh[[j]]
    temp_positives[j] <- sum(mini_preds)
    temp_detection[j] <- 100 * temp_positives[j] / sum(label[folds[[j]]])
    temp_true[j] <- sum((mini_preds[mini_preds == TRUE] == label[folds[[j]]][mini_preds == TRUE]))
    temp_undetect[j] <- sum(label[folds[[j]]]) - temp_true[j]
    temp_true[j] <- 100 * temp_true[j] / sum(length(mini_preds[mini_preds == TRUE]))
    best_mcc <- best_mcc + (temp_mcc[j] / length(folds))
    cat("Fold ", j, ": MCC=", sprintf("%.07f", temp_mcc[j]), " (", sprintf("%04d", temp_positives[j]), " [", sprintf("%05.2f", temp_detection[j]), "%] positives), threshold=", sprintf("%.07f", temp_thresh[j]), " => True positives = ", sprintf("%06.3f", temp_true[j]), "%\n", sep = "")
    
  }
  cat("MCC: ", sprintf("%.07f", mean(temp_mcc)), " + ", sprintf("%.07f", sd(temp_mcc)), "\n", sep = "")
  cat("Threshold: ", sprintf("%.07f", mean(temp_thresh)), " + ", sprintf("%.07f", sd(temp_thresh)), "\n", sep = "")
  cat("Positives: ", sprintf("%06.2f", mean(temp_positives)), " + ", sprintf("%06.2f", sd(temp_positives)), "\n", sep = "")
  cat("Detection Rate %: ", sprintf("%06.3f", mean(temp_detection)), " + ", sprintf("%06.3f", sd(temp_detection)), "\n", sep = "")
  cat("True positives %: ", sprintf("%06.3f", mean(temp_true)), " + ", sprintf("%06.3f", sd(temp_true)), "\n", sep = "")
  cat("Undetected positives: ", sprintf("%07.2f", mean(temp_undetect)), " + ", sprintf("%07.2f", sd(temp_undetect)), "\n", sep = "")
  cat("Average MCC on all data (5 fold): ", sprintf("%.07f", mcc_fixed(y_prob = validationValues, y_true = label, prob = mean(temp_thresh))), ", threshold=", sprintf("%.07f", mean(temp_thresh)), "\n", sep = "")
  cat("Average MCC using all data: ", sprintf("%.07f", mcc_eval_print(y_prob = validationValues, y_true = label)), ", threshold=", sprintf("%.07f", mcc_eval_pred(y_prob = validationValues, y_true = label)), "\n\n\n", sep = "")
  
  
  if (length(predictedValuesCV) > 1) {
    
    # Create overfitted submission from all data
    best_mcc1 <- mcc_eval_pred(y_prob = validationValues, y_true = label)
    submission0_ov <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_ov$Response <- as.numeric(predictedValuesCV > best_mcc1)
    best_count1 <- sum(submission0_ov$Response == 1)
    cat("Submission overfitted threshold on all MCC positives: ", best_count1, "\n\n", sep = "")
    write.csv(submission0_ov, file = file.path(my_script_is_using, paste(my_script_subbed, "_val_", sprintf("%.06f", best_mcc1), "_", best_count1, ".csv", sep = "")), row.names = FALSE)
    
    # Create CV submission from validation
    best_mcc2 <- mean(temp_thresh)
    submission0 <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0$Response <- as.numeric(predictedValuesCV > best_mcc2)
    best_count2 <- sum(submission0$Response == 1)
    cat("Submission average validated threshold on all MCC positives: ", best_count2, "\n\n", sep = "")
    write.csv(submission0, file = file.path(my_script_is_using, paste(my_script_subbed, "_val_", sprintf("%.06f", best_mcc2), "_", best_count2, ".csv", sep = "")), row.names = FALSE)
    
    # Create average of the two previous submissions
    best_mcc3 <- (best_mcc1 + best_mcc2) / 2
    submission0_ex <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_ex$Response <- as.numeric(predictedValuesCV > best_mcc3)
    best_count3 <- sum(submission0_ex$Response == 1)
    cat("Submission average of overfit+validated threshold positives: ", best_count3, "\n\n", sep = "")
    write.csv(submission0_ex, file = file.path(my_script_is_using, paste(my_script_subbed, "_val_", sprintf("%.06f", best_mcc3), "_", best_count3, ".csv", sep = "")), row.names = FALSE)
    
    # Create files for stacker
    write.csv(validationValues, file = file.path(my_script_is_using, "aaa_stacker_preds_train_headerY.csv"), row.names = FALSE)
    write.csv(predictedValuesCV, file = file.path(my_script_is_using, "aaa_stacker_preds_test_headerY.csv"), row.names = FALSE)
    
  }
  
  
  if (length(predictedValues) > 1) {
    
    # Create overfitted submission from all data using full trained model
    best_mcc1_all <- best_mcc1
    submission0_ov_all <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_ov_all$Response <- as.numeric(predictedValues > best_mcc1_all)
    best_count1_all <- sum(submission0_ov_all$Response == 1)
    cat("Submission with all data overfitted threshold on all MCC positives: ", best_count1_all, ". Threshold=", best_mcc1_all, "\n\n", sep = "")
    write.csv(submission0_ov_all, file = file.path(my_script_is_using, paste(my_script_subbed, "_all_", sprintf("%.06f", best_mcc1_all), "_", best_count1_all, ".csv", sep = "")), row.names = FALSE)
    
    # Create CV submission from validation using full trained model
    best_mcc2_all <- best_mcc2
    submission0_all <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_all$Response <- as.numeric(predictedValues > best_mcc2_all)
    best_count2_all <- sum(submission0_all$Response == 1)
    cat("Submission with all data average validated threshold on all MCC positives: ", best_count2_all, ". Threshold=", best_mcc2_all, "\n\n", sep = "")
    write.csv(submission0_all, file = file.path(my_script_is_using, paste(my_script_subbed, "_all_", sprintf("%.06f", best_mcc2_all), "_", best_count2_all, ".csv", sep = "")), row.names = FALSE)
    
    # Create average of the two previous submissions using full trained model
    best_mcc3_all <- best_mcc3
    submission0_ex_all <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_ex_all$Response <- as.numeric(predictedValues > best_mcc3_all)
    best_count3_all <- sum(submission0_ex_all$Response == 1)
    cat("Submission with all data average of overfit+validated threshold positives: ", best_count3_all, ". Threshold=", best_mcc3_all, "\n\n", sep = "")
    write.csv(submission0_ex_all, file = file.path(my_script_is_using, paste(my_script_subbed, "_all_", sprintf("%.06f", best_mcc3_all), "_", best_count3_all, ".csv", sep = "")), row.names = FALSE)
    
    
    
    mini_preds <- predictedValues
    mini_preds <- mini_preds[order(mini_preds, decreasing = TRUE)]
    
    # Create overfitted submission from all data using full trained model using respective positive count
    best_mcc1_all_val <- mini_preds[best_count1 + 1]
    submission0_ov_all_val <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_ov_all_val$Response <- as.numeric(predictedValues > best_mcc1_all_val)
    best_count1_all_val <- sum(submission0_ov_all_val$Response == 1)
    cat("Submission with all data by taking the amount of positives of overfitted threshold on all MCC positives: ", best_count1_all_val, ". Threshold=", best_mcc1_all_val, "\n\n", sep = "")
    write.csv(submission0_ov_all_val, file = file.path(my_script_is_using, paste(my_script_subbed, "_all_val_", sprintf("%.06f", best_mcc1_all_val), "_", best_count1_all_val, ".csv", sep = "")), row.names = FALSE)
    
    # Create CV submission from validation using full trained model using respective positive count
    best_mcc2_all_val <- mini_preds[best_count2 + 1]
    submission0_all_val <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_all_val$Response <- as.numeric(predictedValues > best_mcc2_all_val)
    best_count2_all_val <- sum(submission0_all_val$Response == 1)
    cat("Submission with all data by taking the amount of positives of average validated threshold on all MCC positives: ", best_count2_all_val, ". Threshold=", best_mcc2_all_val, "\n\n", sep = "")
    write.csv(submission0_all_val, file = file.path(my_script_is_using, paste(my_script_subbed, "_all_val_", sprintf("%.06f", best_mcc2_all_val), "_", best_count2_all_val, ".csv", sep = "")), row.names = FALSE)
    
    # Create average of the two previous submissions using full trained model using respective positive count
    best_mcc3_all_val <- mini_preds[best_count3 + 1]
    submission0_ex_all_val <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_ex_all_val$Response <- as.numeric(predictedValues > best_mcc3_all_val)
    best_count3_all_val <- sum(submission0_ex_all_val$Response == 1)
    cat("Submission with all data by taking the amount of positives of average of overfit+validated threshold positives: ", best_count3_all_val, ". Threshold=", best_mcc3_all_val, "\n\n", sep = "")
    write.csv(submission0_ex_all_val, file = file.path(my_script_is_using, paste(my_script_subbed, "_all_val_", sprintf("%.06f", best_mcc3_all_val), "_", best_count3_all_val, ".csv", sep = "")), row.names = FALSE)
    
    # Create submissions using full trained model using total validated positive count
    best_mcc_extra <- mini_preds[sum(temp_positives) + 1]
    submission0_extra <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
    submission0_extra$Response <- as.numeric(predictedValues > best_mcc_extra)
    best_count_extra <- sum(submission0_extra$Response == 1)
    cat("Submission with all data by taking the sum of positives of validated positives: ", best_count_extra, ". Threshold=", best_mcc_extra, "\n\n", sep = "")
    write.csv(submission0_extra, file = file.path(my_script_is_using, paste(my_script_subbed, "_extra_", sprintf("%.06f", best_mcc_extra), "_", best_count_extra, ".csv", sep = "")), row.names = FALSE)
    
    if (!is.na(manual)) {
      
      # Create submissions using full trained model using manual positive count
      best_mcc_extra <- mini_preds[manual + 1]
      submission0_extra <- fread("datasets/sample_submission.csv", header = TRUE, sep = ",", stringsAsFactors = FALSE)
      submission0_extra$Response <- as.numeric(predictedValues > best_mcc_extra)
      best_count_extra <- sum(submission0_extra$Response == 1)
      cat("Submission on selected amount of positives: ", best_count_extra, ". Threshold=", best_mcc_extra, "\nIt needs ", sprintf("%05.2f", 100 * (sum(predictedValues > best_mcc_extra) - sum(predictedValues > best_mcc1_all)) / sum(predictedValues > best_mcc_extra)), "% TP to hold true.\n\n", sep = "")
      write.csv(submission0_extra, file = file.path(my_script_is_using, paste(my_script_subbed, "_manual_", sprintf("%.06f", best_mcc_extra), "_", best_count_extra, ".csv", sep = "")), row.names = FALSE)
      
    }
    
  }
  
  
  cat("```")
  sink()
  
}




AnalysisFunc(label = label,
             folds = folds,
             validationValues = validationValues,
             predictedValuesCV = predictedValuesCV,
             predictedValues = predictedValues,
             manual = 3164)