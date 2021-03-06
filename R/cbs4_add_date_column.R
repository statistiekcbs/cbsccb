#' Convert the time variable into either a date or numeric.
#'
#' Add extra date columns to data set, for the creation of time series or graphics.
#'
#' Time periods in data of CBS are coded: yyyyXXww (e.g. 2018JJ00, 2018MM10, 2018KW02),
#' which contains year (yyyy), type (XX) and index (ww). `cbs4_add_date_column` converts
#' these codes into a [Date()] or `numeric`.
#'
#' `"Date"` will create a date that signifies the start of the period:
#'
#' - "2018JJ00" will turn into "2018-01-01"
#' - "2018KW02" will turn into "2018-04-01"
#'
#' `"numeric"` creates a fractional
#' number which signs the "middle" of the period. e.g. 2018JJ00 -> 2018.5 and
#' 2018KW01 -> 2018.167. This is for the following reasons: otherwise 2018.0 could mean
#' 2018, 2018 Q1 or 2018 Jan, and furthermore 2018.75 is a bit strange for 2018 Q4.
#' If all codes in the dataset have frequency "Y" the numeric output will be `integer`.
#'
#' The `<period_freq>` column indicates the period type / frequency:
#'
#' - `Y`: year
#' - `Q`: quarter
#' - `M`: month
#' - `W`: week
#' - `D`: day
#'
#' @param data `data.frame` retrieved using [cbs4_get_data()]
#' @param date_type Type of date column: "Date", "numeric". See details.
#' @param ... future use.
#' @return original dataset with two added columns: `<period>_Date` and
#' `<period>_freq`. See details.
#' @example ./example/cbs_add_date_column.R
#' @export
#' @family add metadata columns
#' @seealso [cbs4_get_metadata()]
cbs4_add_date_column <- function(data, date_type = c("Date", "numeric"),...){
  # TODO optimize by first converting the PeriodenCodes and then the data.
  #
  if (!(inherits(data, "cbs4_data") || inherits(data, "cbs4_observations"))){
    stop("cbs4_add_date_column only works on data retrieved with cbs4_get_data or cbs4_get_observations."
         , call. = FALSE
    )
  }

  meta <- attr(data, "meta")
  # retrieve period column (using timedimension)
  period_name <- meta$Dimensions$Identifier[meta$Dimensions$Kind == "TimeDimension"][1]
  #period_name <- names(unlist(sapply(x, attr, "is_time")))

  x <- data
  if (!length(period_name)){
    warning("No time dimension found!")
    return(x)
  }

  period <- data[[period_name[1]]]

  PATTERN <- "(\\d{4})(\\w{2})(\\d{2})"

  year   <- as.integer(sub(PATTERN, "\\1", period))
  number <- as.integer(sub(PATTERN, "\\3", period))
  type   <- factor(sub(PATTERN, "\\2", period))

  #TODO add switch for begin / middle / period or number

  # year conversion
  is_year <- type %in% c("JJ")
  is_quarter <- type %in% c("KW")
  is_month <- type %in% c("MM")
  is_week <- type %in% c("W1")
  is_week_part <- type %in% c("X0")
  is_day <- grepl("\\d{2}", type)


  # date
  date_type <- match.arg(date_type)

  if (date_type == "Date"){
    period <- as.POSIXct(character())
    period[is_year] <- ISOdate(year, 1, 1, tz="")[is_year]
    period[is_quarter] <- ISOdate(year, 1 + (number - 1) * 3, 1, tz="")[is_quarter]
    period[is_month] <- ISOdate(year, number, 1, tz="")[is_month]
    period[is_day] <- ISOdate(year, type, number)[is_day]
    period[is_week] <- {
      d <- as.Date(paste0(year, "-1-1")) + 7 * (number - 1)
      # a week starts at monday
      wday <- as.integer(format(d, "%u"))
      d <- d + ((7 - wday - 1) %% 7)
      d
    }[is_week]
    period[is_week_part] <- as.Date(paste0(year, "-1-1"))[is_week_part]

    period <- as.Date(period)
  } else if (date_type == "numeric"){
    period <- numeric()
    period[is_year] <- year[is_year] + 0.5
    period[is_quarter] <- (year + (3*(number - 1) + 2) / 12)[is_quarter]
    period[is_month] <- (year + (number - 0.5) / 12)[is_month]
    period[is_week] <- (year + (number - 0.5)/53)[is_week]
    period[is_week_part] <- year[is_week_part]
    if (all(is_year)){
      period <- as.integer(period)
    }
  }

  type1 <- factor(levels=c("Y", "Q", "M", "D", "W", "X"))
  type1[is_year] <- "Y"
  type1[is_quarter] <- "Q"
  type1[is_month] <- "M"
  type1[is_day]  <- "D"
  type1[is_week] <- "W"
  type1[is_week_part] <- "X"
  type1 <- droplevels(type1)

  # put the column just behind the period column
  i <- which(names(x) == period_name)
  x <- x[c(1:i, i, i:ncol(x))]
  idx <- c(i+1, i+2)
  x[idx] <- list(period, type1)
  names(x)[idx] <- paste0(period_name, paste0("_", c(date_type,"freq")))
  attr(x, "meta") <- meta
  x
}

# x <- cbs4_get_data("84120NED")
# x1 <- cbs4_add_date_column(x)
