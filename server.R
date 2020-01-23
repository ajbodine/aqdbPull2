##===========================================================================##
## /  /  /  /  /  /  /  /  AA /  /  /QQQQQ/  /  /  /  /  /  /  /  /  /  /  / ##
##/  /  /  /  /  /  /  /  AAAA  /  /QQ/  QQ /  /  /  /  /  /  /  /  /  /  /  ##
##  /  /  /  /  /  /  /  AA /AA/  /QQ/  / QQ  /  /  /  /  /  /  /  /  /  /  /##
## /  /  /  /  /  /  /  /AA/ AA  /QQ/  /  /QQ/  /  /  /  /  /  /  /  /  /  / ##
##/  /  /  /  /  /  /  /AAAAAAAA/ QQ  /  / QQ  /  /  /  /  /  /  /  /  /  /  ##
##  /  /  /  /  /  /  / AAAAAAAA  /QQ/  /QQQ  /  /  /  /  /  /  /  /  /  /  /##
## /  /  /  /  /  /  /  AA /  AA /  QQ / QQQQ/  /  /  /  /  /  /  /  /  /  / ##
##/  /  /  /  /  /  /  /AA/  /AA/  / QQQQQ QQQ /DASHBOARD  /  /  /  /  /  /  ##
##  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /  /##
## /  /  /  /  /  /  /  /  /  /  /  /SERVER.R/  /  /  /  /  /  /  /  /  /  / ##
##---------------------------------------------------------------------------##
## \  \  \  \  \  \  \  \ Written by AJB, Ph.D in 2018\  \  \  \  \  \  \  \ ##
##---------------------------------------------------------------------------##
##                                   OVERVIEW                                ##
## This file, server.R, features the server-side processing for the AQ       ##
## Dashboard. All data gathering, data manipulation, and computations as     ##
## well as roughly half of the rendering of client-side page elements are    ##
## governed by the code below. The choice of making the dashboard in R is    ##
## due to a confluence of factors but primarily a result of the convenience  ##
## of having all statistical and visual tools available in a single program. ##
## In other words, all complex psychometric model setup/scoring via the mirt ##
## and mirtCAT packages is paired with the web-development tools in the      ##
## shiny, shinyjs, shiny.semantic, and htmltools packages. This is further   ##
## fleshed out with the useful interactive nature of elements rendered with  ##
## the DT and plotly packages and the ability to produce interactive or      ##
## static reports with rmarkdown and webshot, respectively. R can also       ##
## interpret and render all traditional web-development languages, including ##
## event handling with JS, markup with HTML, and styling with CSS. Data can  ##
## even be pulled using SQL queries via the RMySQL and RJDBC packages.       ##
##---------------------------------------------------------------------------##
##                          STRUCTURE OF THIS DOCUMENT                       ##
## The server.R file in any two-file shiny program is nested within a        ##
## defined server function. Within this function is where all the magic      ##
## happens. Other than the timer object ptm, this file can be split into a   ##
## seried of code "chunks." They are as follows:                             ##
##   1.) JavaScript functions: Although shiny is a very useful and flexible  ##
##       utility, it is not capable of handling all types of interactivity   ##
##       necessary for a good web tool. Because of this shortfall, I've had  ##
##       to write a little custom JavaScript. In particular, the functions   ##
##       there handle tasks like maximizing elements, helping the rail       ##
##       elements maintiain their position, and controlling how the          ##
##       accordion element works.                                            ##
##   2.) R functions: Due to the interwoven nature of any interactive        ##
##       program, functional programming is key. Because computations and    ##
##       display features have to be recomputed and rerendered over and over ##
##       again at the whim of the user, it is much easier to handle such     ##
##       events with functions. The bulk of this document is contained in    ##
##       that chunk, so see each individual function for markup detailing    ##
##       how each one works.                                                 ##
##   3.) Palette: What it says on the tin; contains the colors used in this  ##
##       dashboard. All colors comply with SRALab brand standards.           ##
##   4.) Model Setup: Establishes all predictive and psychometric models.    ##
##       All predictive model output is pulled from the EDW to be applied to ##
##       patients based on their unique characteristics. The psychometric    ##
##       models require their parameters to be pulled from the EDW, then     ##
##       assembled into model objects using utilities from the mirt and      ##
##       mirtCAT packages.                                                   ##
##   5.) Data operations: Contains SQL queries that pull all AQ relevant     ##
##       data from the EDW as well as lists of current patients. The AQ data ##
##       are transformed and modified for scoring and display. The           ##
##       dashboard's patient select table is also rendered at the end of     ##
##       this chunk.                                                         ##
##   6.) Reactive value setup: This dashboard makes heavy usage of shiny's   ##
##       reactive values, or RVs. RVs contain data that a.) are updated as   ##
##       the user makes changes on the dashboard, and b.) need to be         ##
##       available to different environments at any given time. Due to the   ##
##       flexibility of RVs, many of the R functions I've written here do    ##
##       not need to be fed options in order to work properly.               ##
##   7.) Table observer: This chunk essentially "kicks off" the dashboard    ##
##       whenever a patient is selected. In essense, selecting a patient on  ##
##       the Patient Select table runs functions that (conditionally) run a  ##
##       bunch of other functions that eventually results in the dashboard   ##
##       being displayed to the user's specifications. It also contains the  ##
##       download handlers for saveable reports.                             ##
##   8.) shinyjs event handlers: Thankfully, it is not necessary to write    ##
##       JavaScript for all interactivity. The shinyjs package contains a    ##
##       collection of event handlers for a variety of user inputs. For the  ##
##       most part, the handlers I've used here run custom functions when    ##
##       users click on various buttons.                                     ##
##---------------------------------------------------------------------------##
##                             GENERAL PROCESS FLOW                          ##
## Without the user doing anything other than opening the dashoard, this is  ##
## what happens:                                                             ##
##   1.) The JavaScript functions, R functions, and palette are defined.     ##
##   2.) Predictive and psychometric model information is pulled from the    ##
##       EDW and built into R model objects.                                 ##
##   3.) Patient and AQ data are pulled from the EDW, then formatted for the ##
##       dashboard's needs.                                                  ##
##   4.) The Select a Patient table is built and rendered on the dashboard,  ##
##       waiting for the user to select a patient.                           ##
## At this point the dashboard is idle and merely waiting for the user to    ##
## pick someone to look at. Attempting to do anything without selecting a    ##
## patient first will display a notification instructing the user to do so.  ##
## Once a patient is selected:                                               ##
##   5.) The row index for the selected patient is recorded, and its         ##
##       contents are used to select all pulled data relevant to that        ##
##       patient. This information is then saved into a set of RVs that the  ##
##       dashboard will continually make use of until another patient is     ##
##       chosen. The scoring functions for each of the three AQ domains are  ##
##       also run at this point and saved into RVs as well.                  ##
##   6.) The dashboard detects which AQ domain is currently selected to      ##
##       display and renders the corresponding interactive plotly charts.    ##
##   7.) The dashboard finishes loading and awaits further instruction.      ##
##---------------------------------------------------------------------------##
##                              DASHBOARD ELEMENTS                           ##
## The dasbhoard is composed of three primary sections which are further     ##
## subdivided into other individual elements. These are:                     ##
##   1.) Sidebar: The sidebar on the left of the page displays information   ##
##       about the selected patient. The top half gives percent change of    ##
##       patients AQ scores in the chosen domain, and the bottom part        ##
##       contains demographic information that often needs to be referenced  ##
##       when discussing the patient.                                        ##
##   2.) Rail: The rail on the right of the page contains a "remote control" ##
##       that can be used for a wide variety of tasks like changing the      ##
##       AQ domain being displayed, navigating, generating reports, or       ##
##       viewing help. The bottom of the rail contains an accordion element  ##
##       used for editing FIM data.                                          ##
##   3.) Main content: The real meat and potatoes. Located in the center of  ##
##       the page, it contains the Select a Patient table, FIM performance   ##
##       and goals, AQ scores and associated predictive models, and finally, ##
##       the patient timeline, which converts the predictive model to the    ##
##       FIM scale using the AQ scores as an intermediary.                   ##
##---------------------------------------------------------------------------##
##                              TYPES OF USER INPUT                          ##
## Once a patient's information has been displayed, the user has free reign  ##
## to explore that patient's AQ information. These are all of the things     ##
## that the user can do:                                                     ##
##   1.) Change the domain: Upon loading, the dashboard defaults to the      ##
##       self-care domain. The user can switch to mobility and cognition     ##
##       using the orange row of controls on the top right of the screen.    ##
##   2.) Navigate the page: The red row of controls on the top right can be  ##
##       used to jump from page section to page section without scrolling.   ##
##   3.) Generate a report: Clicking one of the two yellow buttons in the    ##
##       control element on the top right will either generate an            ##
##       interactive, self-contained HTML report or a static PNG report more ##
##       suited for printing.                                                ##
##   4.) View the help walkthrough: The purple button on the top right will  ##
##       take the user through a tour of the dashboard's contents and        ##
##       features.                                                           ##
##   5.) Adjust patient characteristics: The predictive and psychometric     ##
##       models make use of certain patient characteristics; namely, their   ##
##       expected length of stay, their medical service, their expected      ##
##       balance level at discharge (i.e., sitting, standing or walking),    ##
##       their expected mode of locomotion at discharge (i.e., wheelchair,   ##
##       walking, or both), and their cognitive diagnosis, if any (i.e.,     ##
##       aphasia, cognitive-communication deficits, right hemisphere         ##
##       dysfunction, brain injury, or speech disorder). Other than medical  ##
##       service, the user can change any of these features for the patient, ##
##       click the Update button, and see how the patient looks in that      ##
##       context.                                                            ##
##   6.) Correct aberrant FIM data: The dashboard does as much as it can to  ##
##       report the correct FIM data, but sometimes adjustment is needed in  ##
##       cases where clinicians may disagree about a patient's functional    ##
##       status or data has not yet been pulled from Cerner to the EDW.      ##
##       expanding the domain-relevent section of the accordion on the lower ##
##       right of the dashboard will allow users to adjust FIM scores, and   ##
##       clicking the "Update FIM" button will enact and render resulting    ##
##       changes.                                                            ##
##   7.) Adjust FIM goals: Clinicians are often required to select goals for ##
##       their patients at the beginning of stay, even in situations where   ##
##       they may not have yet had the proper time to become acquainted with ##
##       the patient. In such cases, it can be useful to adjust the FIM      ##
##       FIM goals and see how they compare with the predictive models.      ##
##---------------------------------------------------------------------------##
##                        A NOTE ABOUT DASHBOARD EDITS                       ##
## If you have somehow found yourself in need of making edits to the server  ##
## side aspects of the dashboard, you have my sincerest apologies. Changes   ##
## anywhere to this document can result in crashing on startup, FUBARed      ##
## displays, or, most dangerously, results that look correct but actually    ##
## aren't. If you do have to edit this (and you have lots of expertise in    ##
## R), here's a few pointers:                                                ##
##   1.) Mimic the process flow of the dashboard. Define the R functions and ##
##       pull the data from the EDW. Then, select an example patient from    ##
##       hp and define rv$row accordingly. Finally, populate the RVs that    ##
##       depend on rv$row. Using an example patient makes debugging go much  ##
##       more quickly.                                                       ##
##   2.) Remember that performing operations with RVs is not possible in a   ##
##       non-interactive context like the one you're in now. Wrap such code  ##
##       in isolate functions before running.                                ##
##   3.) If you're trying to extract the IRT-relevant bits that require R to ##
##       work (as you might be if you're developing this into a proper       ##
##       web-based utility), the main bits you'll need are the model setup   ##
##       chunk (to build the testlet models) and the scoring functions in    ##
##       the R function definitions section (to use them).                   ##
##  Good luck,                                                               ##
##    - AJB                                                                  ##
##===========================================================================##

server <- function(input, output, session){
  
  ptm <- proc.time() # timer start
  
  ## In spite of fitting a testlet model, the scoring function I'm using
  ## doesn't quite prevent paradoxical scores in the MIRT models. Instead, if
  ## this switch is set to 1, marginal scoring (i.e., one testlet at a time) is
  ## performed. If set to 0, IRT (MAP) scoring will be performed in its usual
  ## way.
  marScoSwitch <- 1

  {
  ## Per the shinyjs documentation, it's best to define all JS functions and
  ## run them early in the server file. Loading them here ensures they'll run
  ## in the dashboard like any other JS would on a webpage.
    
  ## This bit keeps the controls on the top right of the screen in position
  ## regardless of where the user scrolls.
  stickyJS <- "
    $(document).ready(function(){
      $('.ui.sticky')
        .sticky({
          context: '#page',
          pushing: false;
        });
    })
  "
  runjs(stickyJS)
  
  ## This handles fullscreening when the Typical Recovery Curve plot is maxed.
  fs2 <- "
    function toggleFullscreen2() {
      if (
        document.fullscreenElement ||
        document.webkitFullscreenElement ||
        document.mozFullScreenElement ||
        document.msFullscreenElement
      ) {
        if (document.exitFullscreen) {
          document.exitFullscreen();
        } else if (document.mozCancelFullScreen) {
          document.mozCancelFullScreen();
        } else if (document.webkitExitFullscreen) {
          document.webkitExitFullscreen();
        } else if (document.msExitFullscreen) {
          document.msExitFullscreen();
        }
      } else {
        element = $('#patTC').get(0);
        if (element.requestFullscreen) {
          element.requestFullscreen();
        } else if (element.mozRequestFullScreen) {
          element.mozRequestFullScreen();
        } else if (element.webkitRequestFullscreen) {
          element.webkitRequestFullscreen(Element.ALLOW_KEYBOARD_INPUT);
        } else if (element.msRequestFullscreen) {
          element.msRequestFullscreen();
        }
      }
    }
    
    document.getElementById('btnFullscreen2').addEventListener('click', function() {
      toggleFullscreen2();
    })
  "
  runjs(fs2)
  
  ## This adds the "addFS" class to the container for the Goal Tracker; plotly
  ## charts will resize to their container, but fullscreening doesn't increase
  ## the size of the container. Adding this class is necessary. In the future,
  ## it may be a good idea to add a JS event handler for the Esc key to remove
  ## the addFS class; currently, the plotly charts don't return to their
  ## initial height and width.
  addFS2 <- "
    $('#btnFullscreen2').on('click', function () {
        $('#patTC').toggleClass('addFS');
    });
  "
  runjs(addFS2)
  
  ## Similar to fs2, but for the Goal Tracker
  fs3 <- "
    function toggleFullscreen3() {
      if (
        document.fullscreenElement ||
        document.webkitFullscreenElement ||
        document.mozFullScreenElement ||
        document.msFullscreenElement
      ) {
        if (document.exitFullscreen) {
          document.exitFullscreen();
        } else if (document.mozCancelFullScreen) {
          document.mozCancelFullScreen();
        } else if (document.webkitExitFullscreen) {
          document.webkitExitFullscreen();
        } else if (document.msExitFullscreen) {
          document.msExitFullscreen();
        }
      } else {
        element = $('#patFIM').get(0);
        if (element.requestFullscreen) {
          element.requestFullscreen();
        } else if (element.mozRequestFullScreen) {
          element.mozRequestFullScreen();
        } else if (element.webkitRequestFullscreen) {
          element.webkitRequestFullscreen(Element.ALLOW_KEYBOARD_INPUT);
        } else if (element.msRequestFullscreen) {
          element.msRequestFullscreen();
        }
      }
    }
    
    document.getElementById('btnFullscreen3').addEventListener('click', function() {
      toggleFullscreen3();
    })
  "
  runjs(fs3)
  
  ## Analogous to addFS2
  addFS3 <- "
    $('#btnFullscreen3').on('click', function () {
        $('#patFIM').toggleClass('addFS');
    });
  "
  runjs(addFS3)
  
  ## Created to handle the fullscreening of the Timeline element; however, the
  ## JS for timevis appears to automatically (and irrevocably) calculate
  ## height. Fullscreening doesn't actually do anything but place the timeline
  ## in the middle of the screen in a white background and mess up the stacking
  ## context of the elements, causing the z-indexes in the pseudo-elements to
  ## show on top of the plot.
  fs4 <- "
    function toggleFullscreen4() {
      if (
        document.fullscreenElement ||
        document.webkitFullscreenElement ||
        document.mozFullScreenElement ||
        document.msFullscreenElement
      ) {
        if (document.exitFullscreen) {
          document.exitFullscreen();
        } else if (document.mozCancelFullScreen) {
          document.mozCancelFullScreen();
        } else if (document.webkitExitFullscreen) {
          document.webkitExitFullscreen();
        } else if (document.msExitFullscreen) {
          document.msExitFullscreen();
        }
      } else {
        element = $('#tlCard').get(0);
        if (element.requestFullscreen) {
          element.requestFullscreen();
        } else if (element.mozRequestFullScreen) {
          element.mozRequestFullScreen();
        } else if (element.webkitRequestFullscreen) {
          element.webkitRequestFullscreen(Element.ALLOW_KEYBOARD_INPUT);
        } else if (element.msRequestFullscreen) {
          element.msRequestFullscreen();
        }
      }
    }

    document.getElementById('btnFullscreen4').addEventListener('click', function() {
      toggleFullscreen4();
    })
  "
  runjs(fs4)

  ## Analogous to the other addFS# functions; but I should also deprecate this.
  addFS4 <- "
    $('#btnFullscreen4').on('click', function () {
        $('#tlCard').toggleClass('addFS');
        $('#patTL').toggleClass('addFS80');
        $('#timeline'.toggleClass('addFS80');
    });
  "
  runjs(addFS4)
  
  ## Handles the accordion element in the Update FIM area. The option forces
  ## other sections of the accordion to close when a new section is opened.
  accordionJS <- "
    $('.accordion').accordion('close others')
  "
  runjs(accordionJS)
  
  ## The name is outdated. This function used to cause a white border to appear
  ## around the currently displayed domain in the Select Domain part of the
  ## top right rail. I've changed the CSS for the "selectedsection" class to
  ## look like a pressed button instead. "notselectedsection" returns it to
  ## its inital state.
  borderJS <- "
    var domainselect = $('#domainselect a').on('click', function (e) {
        var $this = $(this),
            el = domainselect.not(this),
            isSC = $this.is('#scButton');
    
        $this.removeClass('notselectedsection');
        $this.addClass('selectedsection');
        el.addClass('notselectedsection');
    });
  "
  runjs(borderJS)
  
  ## Toggles the background colors when switching domains. The CSS for the
  ## classes below include the rgba versions of the primary dashboard colors
  ## listed in the palette, but with a low alpha value to mute them abit. The
  ## CSS also includes animation options to create a slow fade between colors.
  bgJS <- "
    $('#scButton').click(function() {
      $('body').addClass('sc');
      $('body').removeClass('mob');
      $('body').removeClass('cog');
    });

    $('#mobButton').click(function() {
      $('body').removeClass('sc');
      $('body').addClass('mob');
      $('body').removeClass('cog');
    });

    $('#cogButton').click(function() {
      $('body').removeClass('sc');
      $('body').removeClass('mob');
      $('body').addClass('cog');
    });
  "
  runjs(bgJS)
  
  ## Although the "shrinking" animation that occurs when a chart is loading is
  ## handled by hijacking shiny's "recalculating" class, triggering a
  ## corresponding reverse animation requires a little jQuery silliness. The
  ## setTimeout function (with no duration) requires the browser to recheck the
  ## DOM, adding the "stretchBack" and "stretchBack2" classes and relevant
  ## animations to those elements.
  stretch <- "
    if(!$('#patGoals').hasClass('recalculating')){
       setTimeout(() => $('#patGoals').addClass('stretchBack'), 0);
    }

    if(!$('#patProg').hasClass('recalculating')){
       setTimeout(() => $('#patProg').addClass('stretchBack'), 0);
    }

    if(!$('#patTC').hasClass('recalculating')){
       setTimeout(() => $('#patTC').addClass('stretchBack'), 0);
    }

    if(!$('#patTL').hasClass('recalculating')){
       setTimeout(() => $('#patTL').addClass('stretchBack'), 0);
    }

    if(!$('#patStats').hasClass('recalculating')){
       setTimeout(() => $('#patStats').addClass('stretchBack2'), 0);
    }

    if(!$('#patStats2').hasClass('recalculating')){
       setTimeout(() => $('#patStats2').addClass('stretchBack2'), 0);
    }
  "
  runjs(stretch)
  
  ## I'm going to set this up here because we'll need it later (it doesn't
  ## have to be a "ready" function. I just need it to run once after the
  ## Select a Patient table is created to add shadow to its div.
  showShadow <- "
    $('#dtWrapper').addClass('shadowed');
  "
  
  ## Another bit of jQuery that isn't meant to be run until the patient table
  ## has loaded. This bit is responsible for 1.) Detecting if an element is
  ## on screen, and 2.) handling events in such cases.
  toggleButtons <- "
    $.fn.isInCenter = function() {
      var dTop = $(window).scrollTop();
      var dBot = dTop + $(window).height();
      var centerLine = (dTop + dBot)/2;
      var cardTop = $(this).offset().top;
      var cardBot = cardTop + $(this).height();
      return cardTop < centerLine && cardBot > centerLine;
    };
    
    $(window).on('resize scroll', function() {
      $('#patSelect').each(function() {
        if ($(this).isInCenter()) {
          $('#sapButton').addClass('selectedsection');
        } else {
          $('#sapButton').removeClass('selectedsection');
        }
      });
    });

    $(window).on('resize scroll', function() {
      $('#patProgress').each(function() {
        if ($(this).isInCenter()) {
          $('#trcButton').addClass('selectedsection');
        } else {
          $('#trcButton').removeClass('selectedsection');
        }
      });
    });

    $(window).on('resize scroll', function() {
      $('#patGoal').each(function() {
        if ($(this).isInCenter()) {
          $('#gtButton').addClass('selectedsection');
        } else {
          $('#gtButton').removeClass('selectedsection');
        }
      });
    });

    $(window).on('resize scroll', function() {
      $('#patTimeline').each(function() {
        if ($(this).isInCenter()) {
          $('#tlButton').addClass('selectedsection');
        } else {
          $('#tlButton').removeClass('selectedsection');
        }
      });
    });
  "

  }   # Javascript functions
  
  {
    
  na.locf0 <- function(object, rev = FALSE, maxgap = Inf, coredata = NULL) {
    if(is.null(coredata)) coredata <- inherits(object, "ts") || inherits(object, "zoo") || inherits(object, "its") || inherits(object, "irts")
    if(coredata) {
      x <- object
      object <- if (rev) rev(coredata(object)) else coredata(object)
    } else {
      if(rev) object <- rev(object)
    }
    ok <- which(!is.na(object))
    if(is.na(object[1L])) ok <- c(1L, ok)
    gaps <- diff(c(ok, length(object) + 1L))
    object <- if(any(gaps > maxgap)) {
      .fill_short_gaps(object, rep(object[ok], gaps), maxgap = maxgap)
    } else {
      rep(object[ok], gaps)
    }
    if (rev) object <- rev(object)
    if(coredata) {
      x[] <- object
      return(x)
    } else {
      return(object)
    }
  }
    
  na.locf <- function(object, na.rm = TRUE, rev = FALSE, maxgap = Inf, ...)
  {
      object[] <- lapply(object, na.locf0, rev = rev, maxgap = maxgap)
      if (na.rm) na.omit(object) else object
  }
    
    
  ## Utility for capitalizing the first letter or every word in a list or
  ## vector. Didn't work well for names starting in "Mc" or "O'", so I don't
  ## think this is used anywhere in the code. Names in the patient table in the
  ## dashboard are presented in all caps instead.
  ### - x = the string to perform the capitalization on
  capFirst <- function(x){
    name <- strsplit(x, ' ')[[1]]
    name <- paste(substring(name, 1, 1), tolower(substring(name, 2)),
                  sep = '', collapse = ' '
    )
  }
  
  ## Imputes data forward, meaning that missing data are overwritten with the
  ## most recent non-missing value. Most useful when applied to columns of a
  ## data.frame using apply(),
  ### - x = the data to be imputed
  repeat.before <- function(x){   
    ind <- which(!is.na(x))    
    if(is.na(x[1])){            
      ind <- c(1, ind)
    }
    rep(x[ind], times = diff(c(ind, length(x) + 1)))
  }
  
  ## Expansion of the above function to handle specified missing values when
  ## "missing" is defined in some way other than NA (as with the 88s in the FIM
  ## data). Should probably just combine with the previous function at some
  ## point (set codes = NULL in the options, then add conditional logic for
  ## when !is.null(codes)
  ### - x     = the data to be imputed
  ### - codes = a list or vector of missing data codes (other than NA)
  repeat.before2 <- function(x, codes){   
    ind <- which(!is.na(x))    
    if(is.na(x[1])){            
      ind <- c(1, ind)
    }
    x <- rep(x[ind], times = diff(c(ind, length(x) + 1)))
    ## This probably warrants some explanation. The top part records which
    ## elements are not missing (in addition to adding in the first element if
    ## the first observation is missing as there's nothing to overwrite it
    ## with. At this point, the NAs have been over written with non-NA values
    ## where possible. To understand this second part, it's best to work from
    ## the inside-out. The intersect in the middle pulls out he index of which
    ## observations are neither missing nor part of the given codes. The code
    ## then takes the minimum value, in effect giving the first non-missing,
    ## non-specified value. The second min() takes the minimum between that
    ## first minimum() and the length of the vector. If nothing has to be
    ## imputed, both results will be the length of the vector, causing the
    ## minimum to be the length. The code then creates a sequence between
    ## 1 and the first element that does not need to be overwritten. This
    ## sequence is then combined with all values that are non-missing and
    ## non-specified. The unique values are extracted to create the
    ## indicators. Finally, the returned vector repeats the indicated values
    ## the necessary number of times, effectively recreating the initial vector
    ## with missing and specified values overwritten.
    ind2 <- unique(c(1:min(min(intersect(which(!is.na(x)),
                                         which(!(x %in% codes))
                               )
                           ),
                           length(x)
                       ),
                     which(!(x %in% codes))
                   )
    )
    rep(x[ind2], times = diff(c(ind2, length(x) + 1)))
  }
  
  ## Quick and easy conversion of IRT intercept parameters into IRT difficulty
  ## parameters. See the flexMIRT FAQs for more info on this conversion.
  ### - int = IRT intercept parameters
  ### - slo = IRT slope parameters
  d2b <- function(int, slo){
    ccs <- apply(slo, 1, function(x) sqrt(sum((x / 1.7)^2, na.rm = T)))
    bs <- -int/ccs
  }
  
  ## Splits data.frames into a list of data frames by day, then takes the
  ## minimum value of of each column.
  ### - Data     = the data.frame to apply this function to
  ### - byCol    = the column to split the data by (usually assessemntDate for
  ###              the dasbhoard, but it doesn't have to be)
  ### - itemCols = the column indices to apply this function to
  ### - qi       = deprecated; should set to F
  minByDay <- function(data, byCol, itemCols, qi = F){
    dataSplit <- split(data, data[, byCol])
    for(i in 1:length(dataSplit)){
      entry <- as.data.frame(matrix(unlist(dataSplit[i]),
                                    ncol = dim(data)[2]),
                             stringsAsFactors = F
      )
      colnames(entry) <- colnames(data)
      entryHold <- data.frame(matrix(NA, ncol = ncol(data), nrow = 1))
      colnames(entryHold) <- colnames(entry)
      for(j in itemCols){
        entryHold[, j] <- ifelse(all(is.na(entry[, j])),
                                 NA, min(entry[, j], na.rm = T)
        )
      }
      entryHold$FIN <- tail(entry$FIN, 1)
      entryHold$MRN <- tail(entry$MRN, 1)
      if(length(grep('-', tail(entry$assessmentDate, 1))) < 1){
        entryHold$assessmentDate <- as.Date(
                                      as.numeric(
                                        tail(entry$assessmentDate, 1)
                                      ),
                                      origin = '1970-01-01'
        )
      }else{
        entryHold$assessmentDate <- as.Date(tail(entry$assessmentDate, 1))
      }
      entryHold$FINAD <- tail(entry$FINAD, 1)
      if(qi == T){
        entryHold$canWalk <- ifelse(
                               length(
                                 tail(entry$canWalk[!is.na(entry$canWalk)], 1)
                               ) > 0,
                               tail(entry$canWalk[!is.na(entry$canWalk)], 1),
                               NA
        )
      }
      entryHold <- split(entryHold, entryHold$FINAD)
      dataSplit <- replace(dataSplit, i, entryHold)
    }
    returnData <- do.call('rbind', dataSplit)
    returnData
  }
  
  ## Pastes two strings together into a single string with a period in between.
  ## This is done fairly often in the code to create good merge/join columns,
  ## so this is more of a convenience function than an absolute necessity.
  ### - a = the first string
  ### - b = the second string
  pasteFun <- function(a, b){
    paste(a, b, sep = '.')
  }
  
  ## Converts a series into the same range as another series. Note that the
  ## distances between elements will be proportional as the function is linear.
  ## Note: the "a" and "b" options could be eliminiated by adding:
  ##    a <- min(c, na.rm = T)
  ##    b <- max(c, na.rm = T)
  ## to the function.
  ### - a = minimum of the "from" series
  ### - b = maximum of the "from" series
  ### - y = minimum of the "to" series
  ### - z = maximum of the "to" series
  ### - c = the "from" series to be converted
  conv <- function(a, b, y, z, c){
  	x <- ((c - a) * (z - y) / (b - a)) + y
  	x
  }
  
  ## This function converts lists into data.frames. Although I perform that
  ## transformation throughout the dashboard, I forgot I wrote this function to
  ## clean it up. Whoops. Leaving it here for future code cleanups if we go
  ## into production. Could probably use an option number of rows to allow for
  ## better control of the resultant data.frame.
  ### - l = name of the list to apply the function to
  list2df <- function(l){
    df <- data.frame(matrix(unlist(l), ncol = length(l), byrow = F),
                     stringsAsFactors = F
    )
    colnames(df) <- names(l)
    df
  }
  
  ## The scoring function for the AQ-SC. Look within the function for
  ## additional mark-up.
  ### - data  = a data.frame containing AQ-SC data
  ### - group = the balance group for the patient being scored
  scoFunSCFIM <- function(data, group){
    ## For sitting balance (FIST) patients...
    if(group == 1){
      ## Select the items relevant to this group
      scoreData <- data[, c(5:10, 22:56)]
      ## Define SC assessment areas and FIM items
      balIts <- 1:6; uefIts <- 7:23; swlIts <- 24:35; fimIts <- 36:41
      ## In cases where 88s are in the score data, replace them with missing
      ## values
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                   function(x) ifelse(x < 7 && !is.na(x),
                                                      x, NA
                                   )
      )
      ## Forward impute if there's more than one row
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      ## Drop rows with all missing values. If all data are missing, create an
      ## empty data.frame with the correct column names
      dropRows <- which(apply(scoreData2, 1, function(x) all(is.na(x))) == T)
      if(length(dropRows) > 0){
        scoreData2 <- scoreData2[-dropRows, ]
        if(is.null(dim(scoreData2))){
          cn <- names(scoreData2)
          scoreData2 <- as.data.frame(matrix(scoreData2, nrow = 1))
          colnames(scoreData2) <- cn
        }
      }
      ## Score the data if any exist and format the results into a useful
      ## format; otherwise, just create a data.frame with missing values
      ## and the correct number of columns.
      if(dim(scoreData2)[1] > 0){
        patScoSC <- as.data.frame(fscores(scModSiBal,
                                          response.pattern = scoreData2,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = siBalMeans, cov = scLTCovSiBal
                                  )
        )
        colnames(patScoSC) <- c(colnames(scoreData2)[1:41], 'sc', 'uef', 'swl',
                                'bal', 'fim', 'scSE', 'uefSE', 'swlSE',
                                'balSE', 'fimSE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(7:23)]))){
            scoreData2_uef <- scoreData2
            scoreData2_uef[, c(1:6, 24:41)] <- NA
            naPos <- which(apply(scoreData2_uef[, c(7:23)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_uef[naPos, 7] <- 1
            }
            patScoSC_uef <- as.data.frame(
                              fscores(scModSiBal,
                                      response.pattern = scoreData2_uef,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = siBalMeans,
                                      cov = scLTCovSiBal
                              )
            )
            colnames(patScoSC_uef) <- c(colnames(scoreData2)[1:41], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$uef <- patScoSC_uef$uef
            patScoSC$uefSE <- patScoSC_uef$uefSE
            if(length(naPos) > 0){
              patScoSC$uef[naPos] <- NA
              patScoSC$uefSE[naPos] <- NA
            }
          }else{
              patScoSC$uef <- NA
              patScoSC$uefSE <- NA
          }
          if(any(!is.na(scoreData2[, c(24:35)]))){
            scoreData2_swl <- scoreData2
            scoreData2_swl[, c(1:23, 36:41)] <- NA
            naPos <- which(apply(scoreData2_swl[, c(24:35)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_swl[naPos, 24] <- 1
            }
            patScoSC_swl <- as.data.frame(
                              fscores(scModSiBal,
                                      response.pattern = scoreData2_swl,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = siBalMeans,
                                      cov = scLTCovSiBal
                              )
            )
            colnames(patScoSC_swl) <- c(colnames(scoreData2)[1:41], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$swl <- patScoSC_swl$swl
            patScoSC$swlSE <- patScoSC_swl$swlSE
            if(length(naPos) > 0){
              patScoSC$swl[naPos] <- NA
              patScoSC$swlSE[naPos] <- NA
            }
          }else{
              patScoSC$swl <- NA
              patScoSC$swlSE <- NA
          }
          if(any(!is.na(scoreData2[, c(1:6)]))){
            scoreData2_bal <- scoreData2
            scoreData2_bal[, c(7:41)] <- NA
            naPos <- which(apply(scoreData2_bal[, c(1:12)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_bal[naPos, 1] <- 1
            }
            patScoSC_bal <- as.data.frame(
                              fscores(scModSiBal,
                                      response.pattern = scoreData2_bal,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = siBalMeans,
                                      cov = scLTCovSiBal
                              )
            )
            colnames(patScoSC_bal) <- c(colnames(scoreData2)[1:41], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$bal <- patScoSC_bal$bal
            patScoSC$balSE <- patScoSC_bal$balSE
            if(length(naPos) > 0){
              patScoSC$bal[naPos] <- NA
              patScoSC$balSE[naPos] <- NA
            }
          }else{
              patScoSC$bal <- NA
              patScoSC$balSE <- NA
          }
        }
      }else{
        patScoSC <- as.data.frame(matrix(rep(NA,
                                             length(colnames(scoreData2)) + 10
                                         ), nrow = 1)
        )
        colnames(patScoSC) <- c(colnames(scoreData2)[1:41], 'sc', 'uef', 'swl',
                                'bal', 'fim', 'scSE', 'uefSE', 'swlSE',
                                'balSE', 'fimSE'
        )
      }
      ## This part "corrects" the IRT scores when improvements in unrelated
      ## areas would reduce a patient's score in the focal area. This is a
      ## byproduct of the mirt and mirtCAT packages not allowing specification
      ## of a testlet model explicitly. As soon as Phil Chalmers changes that,
      ## these sections should be eliminated and testlet models should be
      ## specified a priori.
      if(marScoSwitch == 0){
        uefCorrect <- patScoSC[, c(7:23, 43)]
        if(nrow(uefCorrect) > 1){
          for(i in 2:nrow(uefCorrect)){
            diffScoCheck <- uefCorrect$uef[i] != uefCorrect$uef[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(uefCorrect[i, 1:17])) &&
                 all(is.na(uefCorrect[(i - 1), 1:17])))
              {
                uefCorrect$uef[(i)] <- uefCorrect$uef[(i - 1)]
              }else if(any(!is.na(uefCorrect[i, 1:17])) &&
                       any(!is.na(uefCorrect[(i - 1), 1:17])))
              {
                gtCheck <- which((uefCorrect[i, 1:17] >=
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                ltCheck <- which((uefCorrect[i, 1:17] <=
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                eqCheck <- which((uefCorrect[i, 1:17] ==
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                naCheck <- sum(is.na(uefCorrect[i, 1:17])) <
                           sum(is.na(uefCorrect[(i - 1), 1:17]))
                if(length(gtCheck) == 0 &&
                   (uefCorrect$uef[i] < uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (uefCorrect$uef[i] > uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (uefCorrect$uef[i] != uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
              }
            }
          }
          patScoSC$uef <- uefCorrect$uef
        }
        swlCorrect <- patScoSC[, c(24:35, 44)]
        if(nrow(swlCorrect) > 1){
          for(i in 2:nrow(swlCorrect)){
            diffScoCheck <- swlCorrect$swl[i] != swlCorrect$swl[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(swlCorrect[i, 1:12])) &&
                 all(is.na(swlCorrect[(i - 1), 1:12])))
              {
                swlCorrect$swl[(i)] <- swlCorrect$swl[(i - 1)]
              }else if(any(!is.na(swlCorrect[i, 1:12])) &&
                       any(!is.na(swlCorrect[(i - 1), 1:12])))
              {
                gtCheck <- which((swlCorrect[i, 1:12] >=
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                ltCheck <- which((swlCorrect[i, 1:12] <=
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                eqCheck <- which((swlCorrect[i, 1:12] ==
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                naCheck <- sum(is.na(swlCorrect[i, 1:12])) <
                           sum(is.na(swlCorrect[(i - 1), 1:12]))
                if(length(gtCheck) == 0 &&
                   (swlCorrect$swl[i] < swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (swlCorrect$swl[i] > swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (swlCorrect$swl[i] != swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
              }
            }
          }
          patScoSC$swl <- swlCorrect$swl
        }
        balCorrect <- patScoSC[, c(1:6, 45)]
        if(nrow(balCorrect) > 1){
          for(i in 2:nrow(balCorrect)){
            diffScoCheck <- balCorrect$bal[i] != balCorrect$bal[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(balCorrect[i, 1:6])) &&
                 all(is.na(balCorrect[(i - 1), 1:6])))
              {
                balCorrect$bal[(i)] <- balCorrect$bal[(i - 1)]
              }else if(any(!is.na(balCorrect[i, 1:6])) &&
                       any(!is.na(balCorrect[(i - 1), 1:6])))
              {
                gtCheck <- which((balCorrect[i, 1:6] >=
                                 balCorrect[(i - 1), 1:6]) == F
                )
                ltCheck <- which((balCorrect[i, 1:6] <=
                                  balCorrect[(i - 1), 1:6]) == F
                )
                eqCheck <- which((balCorrect[i, 1:6] ==
                                  balCorrect[(i - 1), 1:6]) == F
                )
                naCheck <- sum(is.na(balCorrect[i, 1:6])) <
                           sum(is.na(balCorrect[(i - 1), 1:6]))
                if(length(gtCheck) == 0 &&
                   (balCorrect$bal[i] < balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (balCorrect$bal[i] > balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (balCorrect$bal[i] != balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
              }
            }
          }
          patScoSC$bal <- balCorrect$bal
        }
      }
      ## This sets the assessmentDate column to control for dropped rows
      if(length(dropRows) > 0){
        ad <- data$assessmentDate[-dropRows]
        ad <- sapply(ad, function(x) ifelse(length(x) == 0, NA, x))
        ad <- as.Date(ad)
      }else{
        ad <- data$assessmentDate
      }
      ## Set up dataframe containing scores and SEs
      scores <- data.frame(assessmentDate = ad, sc = patScoSC$sc,
                           bal = patScoSC$bal, uef = patScoSC$uef,
                           swl = patScoSC$swl, fim = patScoSC$fim,
                           scSE = patScoSC$scSE, balSE = patScoSC$balSE,
                           uefSE = patScoSC$uefSE, swlSE = patScoSC$swlSE,
                           fimSE = patScoSC$fimSE
      )
      ## Because of the imputation done to compute scores, assessment area
      ## scores are also imputed similarly. This would cause issues with
      ## plotting. Instead, dates on which no measures for an assessment
      ## were assessed will have missing scores for that area.
      if(length(dropRows) > 0){
        if(any(!is.na(ad))){
          naMat <- data.frame(scInd = rep(1, dim(scoreData2)[1]),
                              balInd = apply(scoreData[-dropRows, balIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              ),
                              uefInd = apply(scoreData[-dropRows, uefIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              ),
                              swlInd = apply(scoreData[-dropRows, swlIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              ),
                              fimInd = apply(scoreData[-dropRows, fimIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              )
          )
        }else{
          naMat <- NA
        }
      }else{
        naMat <- data.frame(scInd = rep(1, dim(scoreData2)[1]),
                            balInd = apply(scoreData[, balIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            ),
                            uefInd = apply(scoreData[, uefIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            ),
                            swlInd = apply(scoreData[, swlIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            ),
                            fimInd = apply(scoreData[, fimIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            )
        )
      }
      scores[, 2:6] <- scores[, 2:6] * naMat
      scores[, 7:11] <- scores[, 7:11] * naMat
    ## Otherwise, if the patient is in the standing balance (BBS) group...
    }else if(group == 2){
      scoreData <- data[, c(5:16, 22:56)]
      balIts <- 1:12; uefIts <- 13:29; swlIts <- 30:41; fimIts <- 41:47
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                  function(x) ifelse(x < 7 && !is.na(x), x, NA)
      )
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      dropRows <- which(apply(scoreData2, 1, function(x) all(is.na(x))) == T)
      if(length(dropRows) > 0){
        scoreData2 <- scoreData2[-dropRows, ]
        if(is.null(dim(scoreData2))){
          cn <- names(scoreData2)
          scoreData2 <- as.data.frame(matrix(scoreData2, nrow = 1))
          colnames(scoreData2) <- cn
        }
      }
      if(dim(scoreData2)[1] > 0){
        patScoSC <- as.data.frame(fscores(scModStBal,
                                          response.pattern = scoreData2,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = stBalMeans,
                                          cov = scLTCovStBal
                                  )
        )
        colnames(patScoSC) <- c(colnames(scoreData2)[1:47], 'sc', 'uef', 'swl',
                                'bal', 'fim', 'scSE', 'uefSE', 'swlSE',
                                'balSE', 'fimSE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(13:29)]))){
            scoreData2_uef <- scoreData2
            scoreData2_uef[, c(1:12, 30:47)] <- NA
            naPos <- which(apply(scoreData2_uef[, c(13:29)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_uef[naPos, 13] <- 1
            }
            patScoSC_uef <- as.data.frame(
                              fscores(scModStBal,
                                      response.pattern = scoreData2_uef,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = stBalMeans,
                                      cov = scLTCovStBal
                              )
            )
            colnames(patScoSC_uef) <- c(colnames(scoreData2)[1:47], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$uef <- patScoSC_uef$uef
            patScoSC$uefSE <- patScoSC_uef$uefSE
            if(length(naPos) > 0){
              patScoSC$uef[naPos] <- NA
              patScoSC$uefSE[naPos] <- NA
            }
          }else{
              patScoSC$uef <- NA
              patScoSC$uefSE <- NA
          }
          if(any(!is.na(scoreData2[, c(30:41)]))){
            scoreData2_swl <- scoreData2
            scoreData2_swl[, c(1:29, 42:47)] <- NA
            naPos <- which(apply(scoreData2_swl[, c(30:41)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_swl[naPos, 30] <- 1
            }
            patScoSC_swl <- as.data.frame(
                              fscores(scModStBal,
                                      response.pattern = scoreData2_swl,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = stBalMeans,
                                      cov = scLTCovStBal
                              )
            )
            colnames(patScoSC_swl) <- c(colnames(scoreData2)[1:47], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$swl <- patScoSC_swl$swl
            patScoSC$swlSE <- patScoSC_swl$swlSE
            if(length(naPos) > 0){
              patScoSC$swl[naPos] <- NA
              patScoSC$swlSE[naPos] <- NA
            }
          }else{
              patScoSC$swl <- NA
              patScoSC$swlSE <- NA
          }
          if(any(!is.na(scoreData2[, c(1:12)]))){
            scoreData2_bal <- scoreData2
            scoreData2_bal[, c(13:47)] <- NA
            naPos <- which(apply(scoreData2_bal[, c(1:12)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_bal[naPos, 1] <- 1
            }
            patScoSC_bal <- as.data.frame(
                              fscores(scModStBal,
                                      response.pattern = scoreData2_bal,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = stBalMeans,
                                      cov = scLTCovStBal
                              )
            )
            colnames(patScoSC_bal) <- c(colnames(scoreData2)[1:47], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$bal <- patScoSC_bal$bal
            patScoSC$balSE <- patScoSC_bal$balSE
            if(length(naPos) > 0){
              patScoSC$bal[naPos] <- NA
              patScoSC$balSE[naPos] <- NA
            }
          }else{
              patScoSC$bal <- NA
              patScoSC$balSE <- NA
          }
        }
      }else{
        patScoSC <- as.data.frame(
                      matrix(rep(NA, length(colnames(scoreData2)) + 10),
                             nrow = 1
                      )
        )
        colnames(patScoSC) <- c(colnames(scoreData2)[1:47], 'sc', 'uef', 'swl',
                                'bal', 'fim', 'scSE', 'uefSE', 'swlSE', 'balSE',
                                'fimSE'
        )
      }
      if(marScoSwitch == 0){
        uefCorrect <- patScoSC[, c(13:29, 49)]
        if(nrow(uefCorrect) > 1){
          for(i in 2:nrow(uefCorrect)){
            diffScoCheck <- uefCorrect$uef[i] != uefCorrect$uef[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(uefCorrect[i, 1:17])) &&
                 all(is.na(uefCorrect[(i - 1), 1:17])))
              {
                uefCorrect$uef[(i)] <- uefCorrect$uef[(i - 1)]
              }else if(any(!is.na(uefCorrect[i, 1:17])) &&
                       any(!is.na(uefCorrect[(i - 1), 1:17])))
              {
                gtCheck <- which((uefCorrect[i, 1:17] >=
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                ltCheck <- which((uefCorrect[i, 1:17] <=
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                eqCheck <- which((uefCorrect[i, 1:17] ==
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                naCheck <- sum(is.na(uefCorrect[i, 1:17])) <
                           sum(is.na(uefCorrect[(i - 1), 1:17]))
                if(length(gtCheck) == 0 &&
                   (uefCorrect$uef[i] < uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (uefCorrect$uef[i] > uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (uefCorrect$uef[i] != uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
              }
            }
          }
          patScoSC$uef <- uefCorrect$uef
        }
        swlCorrect <- patScoSC[, c(30:41, 50)]
        if(nrow(swlCorrect) > 1){
          for(i in 2:nrow(swlCorrect)){
            diffScoCheck <- swlCorrect$swl[i] != swlCorrect$swl[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(swlCorrect[i, 1:12])) &&
                 all(is.na(swlCorrect[(i - 1), 1:12])))
              {
                swlCorrect$swl[(i)] <- swlCorrect$swl[(i - 1)]
              }else if(any(!is.na(swlCorrect[i, 1:12])) &&
                       any(!is.na(swlCorrect[(i - 1), 1:12])))
              {
                gtCheck <- which((swlCorrect[i, 1:12] >=
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                ltCheck <- which((swlCorrect[i, 1:12] <=
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                eqCheck <- which((swlCorrect[i, 1:12] ==
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                naCheck <- sum(is.na(swlCorrect[i, 1:12])) <
                           sum(is.na(swlCorrect[(i - 1), 1:12]))
                if(length(gtCheck) == 0 &&
                   (swlCorrect$swl[i] < swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (swlCorrect$swl[i] > swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (swlCorrect$swl[i] != swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
              }
            }
          }
          patScoSC$swl <- swlCorrect$swl
        }
        balCorrect <- patScoSC[, c(1:12, 51)]
        if(nrow(balCorrect) > 1){
          for(i in 2:nrow(balCorrect)){
            diffScoCheck <- balCorrect$bal[i] != balCorrect$bal[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(balCorrect[i, 1:12])) &&
                 all(is.na(balCorrect[(i - 1), 1:12])))
              {
                balCorrect$bal[(i)] <- balCorrect$bal[(i - 1)]
              }else if(any(!is.na(balCorrect[i, 1:12])) &&
                       any(!is.na(balCorrect[(i - 1), 1:12])))
              {
                gtCheck <- which((balCorrect[i, 1:12] >=
                                  balCorrect[(i - 1), 1:12]) == F
                )
                ltCheck <- which((balCorrect[i, 1:12] <=
                                  balCorrect[(i - 1), 1:12]) == F
                )
                eqCheck <- which((balCorrect[i, 1:12] ==
                                  balCorrect[(i - 1), 1:12]) == F
                )
                naCheck <- sum(is.na(balCorrect[i, 1:12])) <
                           sum(is.na(balCorrect[(i - 1), 1:12]))
                if(length(gtCheck) == 0 &&
                   (balCorrect$bal[i] < balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (balCorrect$bal[i] > balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (balCorrect$bal[i] != balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
              }
            }
          }
          patScoSC$bal <- balCorrect$bal
        }
      }
      if(length(dropRows) > 0){
        ad <- data$assessmentDate[-dropRows]
        ad <- sapply(ad, function(x) ifelse(length(x) == 0, NA, x))
        ad <- as.Date(ad)
      }else{
        ad <- data$assessmentDate
      }
      scores <- data.frame(assessmentDate = ad,
                           sc = patScoSC$sc, bal = patScoSC$bal,
                           uef = patScoSC$uef, swl = patScoSC$swl,
                           fim = patScoSC$fim, scSE = patScoSC$scSE,
                           balSE = patScoSC$balSE, uefSE = patScoSC$uefSE,
                           swlSE = patScoSC$swlSE, fimSE = patScoSC$fimSE
      )
      if(length(dropRows) > 0){
        if(any(!is.na(ad))){
          naMat <- data.frame(scInd = rep(1, dim(scoreData2)[1])[-dropRows],
                              balInd = apply(scoreData[-dropRows, balIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              ),
                              uefInd = apply(scoreData[-dropRows, uefIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              ),
                              swlInd = apply(scoreData[-dropRows, swlIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              ),
                              fimInd = apply(scoreData[-dropRows, fimIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                             )
                              )
          )
        }else{
          naMat <- NA
        }
      }else{
        naMat <- data.frame(scInd = rep(1, dim(scoreData2)[1]),
                            balInd = apply(scoreData[, balIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            ),
                            uefInd = apply(scoreData[, uefIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            ),
                            swlInd = apply(scoreData[, swlIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            ),
                            fimInd = apply(scoreData[, fimIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                           )
                            )
        )
      }
      scores[, 2:6] <- scores[, 2:6] * naMat
      scores[, 7:11] <- scores[, 7:11] * naMat
    }else if(group == 3){
      scoreData <- data[, c(11:56)]
      balIts <- 1:11; uefIts <- 12:28; swlIts <- 29:40; fimIts <- 41:46
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                  function(x) ifelse(x < 7 && !is.na(x), x, NA)
      )
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      dropRows <- which(apply(scoreData2, 1, function(x) all(is.na(x))) == T)
      if(length(dropRows) > 0){
        scoreData2 <- scoreData2[-dropRows, ]
        if(is.null(dim(scoreData2))){
          cn <- names(scoreData2)
          scoreData2 <- as.data.frame(matrix(scoreData2, nrow = 1))
          colnames(scoreData2) <- cn
        }
      }
      if(dim(scoreData2)[1] > 0){
        patScoSC <- as.data.frame(fscores(scModWaBal,
                                          response.pattern = scoreData2,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = waBalMeans, cov = scLTCovWaBal
        ))
        colnames(patScoSC) <- c(colnames(scoreData2)[1:46], 'sc', 'uef', 'swl',
                                'bal', 'fim', 'scSE', 'uefSE', 'swlSE',
                                'balSE', 'fimSE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(12:28)]))){
            scoreData2_uef <- scoreData2
            scoreData2_uef[, c(1:11, 29:46)] <- NA
            naPos <- which(apply(scoreData2_uef[, c(12:28)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_uef[naPos, 12] <- 1
            }
            patScoSC_uef <- as.data.frame(
                              fscores(scModWaBal,
                                      response.pattern = scoreData2_uef,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = waBalMeans,
                                      cov = scLTCovWaBal
                              )
            )
            colnames(patScoSC_uef) <- c(colnames(scoreData2)[1:46], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$uef <- patScoSC_uef$uef
            patScoSC$uefSE <- patScoSC_uef$uefSE
            if(length(naPos) > 0){
              patScoSC$uef[naPos] <- NA
              patScoSC$uefSE[naPos] <- NA
            }
          }else{
              patScoSC$uef <- NA
              patScoSC$uefSE <- NA
          }
          if(any(!is.na(scoreData2[, c(29:40)]))){
            scoreData2_swl <- scoreData2
            scoreData2_swl[, c(1:28, 41:46)] <- NA
            naPos <- which(apply(scoreData2_swl[, c(29:40)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_swl[naPos, 29] <- 1
            }
            patScoSC_swl <- as.data.frame(
                              fscores(scModWaBal,
                                      response.pattern = scoreData2_swl,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = waBalMeans,
                                      cov = scLTCovWaBal
                              )
            )
            colnames(patScoSC_swl) <- c(colnames(scoreData2)[1:46], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$swl <- patScoSC_swl$swl
            patScoSC$swlSE <- patScoSC_swl$swlSE
            if(length(naPos) > 0){
              patScoSC$swl[naPos] <- NA
              patScoSC$swlSE[naPos] <- NA
            }
          }else{
              patScoSC$swl <- NA
              patScoSC$swlSE <- NA
          }
          if(any(!is.na(scoreData2[, c(1:11)]))){
            scoreData2_bal <- scoreData2
            scoreData2_bal[, c(12:46)] <- NA
            naPos <- which(apply(scoreData2_bal[, c(1:11)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_bal[naPos, 1] <- 1
            }
            patScoSC_bal <- as.data.frame(
                              fscores(scModWaBal,
                                      response.pattern = scoreData2_bal,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = waBalMeans,
                                      cov = scLTCovWaBal
                              )
            )
            colnames(patScoSC_bal) <- c(colnames(scoreData2)[1:46], 'sc',
                                        'uef', 'swl', 'bal', 'fim', 'scSE',
                                        'uefSE', 'swlSE', 'balSE', 'fimSE'
            )
            patScoSC$bal <- patScoSC_bal$bal
            patScoSC$balSE <- patScoSC_bal$balSE
            if(length(naPos) > 0){
              patScoSC$bal[naPos] <- NA
              patScoSC$balSE[naPos] <- NA
            }
          }else{
              patScoSC$bal <- NA
              patScoSC$balSE <- NA
          }
        }
      }else{
        patScoSC <- as.data.frame(matrix(rep(NA,
                                             length(colnames(scoreData2)) + 10
                                         ), nrow = 1)
        )
        colnames(patScoSC) <- c(colnames(scoreData2)[1:46], 'sc', 'uef', 'swl',
                                'bal', 'fim', 'scSE', 'uefSE', 'swlSE', 'balSE',
                                'fimSE'
        )
      }
      if(marScoSwitch == 0){
        uefCorrect <- patScoSC[, c(12:28, 48)]
        if(nrow(uefCorrect) > 1){
          for(i in 2:nrow(uefCorrect)){
            diffScoCheck <- uefCorrect$uef[i] != uefCorrect$uef[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(uefCorrect[i, 1:17])) &&
                 all(is.na(uefCorrect[(i - 1), 1:17])))
              {
                uefCorrect$uef[(i)] <- uefCorrect$uef[(i - 1)]
              }else if(any(!is.na(uefCorrect[i, 1:17])) &&
                       any(!is.na(uefCorrect[(i - 1), 1:17])))
              {
                gtCheck <- which((uefCorrect[i, 1:17] >=
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                ltCheck <- which((uefCorrect[i, 1:17] <=
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                eqCheck <- which((uefCorrect[i, 1:17] ==
                                  uefCorrect[(i - 1), 1:17]) == F
                )
                naCheck <- sum(is.na(uefCorrect[i, 1:17])) <
                           sum(is.na(uefCorrect[(i - 1), 1:17]))
                if(length(gtCheck) == 0 &&
                   (uefCorrect$uef[i] < uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (uefCorrect$uef[i] > uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (uefCorrect$uef[i] != uefCorrect$uef[(i - 1)]) &&
                   !naCheck)
                {
                  uefCorrect$uef[i] <- uefCorrect$uef[(i - 1)]
                }
              }
            }
          }
          patScoSC$uef <- uefCorrect$uef
        }
        swlCorrect <- patScoSC[, c(29:40, 49)]
        if(nrow(swlCorrect) > 1){
          for(i in 2:nrow(swlCorrect)){
            diffScoCheck <- swlCorrect$swl[i] != swlCorrect$swl[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(swlCorrect[i, 1:12])) &&
                 all(is.na(swlCorrect[(i - 1), 1:12])))
              {
                swlCorrect$swl[(i)] <- swlCorrect$swl[(i - 1)]
              }else if(any(!is.na(swlCorrect[i, 1:12])) &&
                       any(!is.na(swlCorrect[(i - 1), 1:12])))
              {
                gtCheck <- which((swlCorrect[i, 1:12] >=
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                ltCheck <- which((swlCorrect[i, 1:12] <=
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                eqCheck <- which((swlCorrect[i, 1:12] ==
                                  swlCorrect[(i - 1), 1:12]) == F
                )
                naCheck <- sum(is.na(swlCorrect[i, 1:12])) <
                           sum(is.na(swlCorrect[(i - 1), 1:12]))
                if(length(gtCheck) == 0 &&
                   (swlCorrect$swl[i] < swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (swlCorrect$swl[i] > swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (swlCorrect$swl[i] != swlCorrect$swl[(i - 1)]) &&
                   !naCheck)
                {
                  swlCorrect$swl[i] <- swlCorrect$swl[(i - 1)]
                }
              }
            }
          }
          patScoSC$swl <- swlCorrect$swl
        }
        balCorrect <- patScoSC[, c(1:11, 50)]
        if(nrow(balCorrect) > 1){
          for(i in 2:nrow(balCorrect)){
            diffScoCheck <- balCorrect$bal[i] != balCorrect$bal[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(balCorrect[i, 1:11])) &&
                 all(is.na(balCorrect[(i - 1), 1:11])))
              {
                balCorrect$bal[(i)] <- balCorrect$bal[(i - 1)]
              }else if(any(!is.na(balCorrect[i, 1:11])) &&
                       any(!is.na(balCorrect[(i - 1), 1:11])))
              {
                gtCheck <- which((balCorrect[i, 1:11] >=
                                  balCorrect[(i - 1), 1:11]) == F
                )
                ltCheck <- which((balCorrect[i, 1:11] <=
                                  balCorrect[(i - 1), 1:11]) == F
                )
                eqCheck <- which((balCorrect[i, 1:11] ==
                                  balCorrect[(i - 1), 1:11]) == F
                )
                naCheck <- sum(is.na(balCorrect[i, 1:11])) <
                           sum(is.na(balCorrect[(i - 1), 1:11]))
                if(length(gtCheck) == 0 &&
                   (balCorrect$bal[i] < balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (balCorrect$bal[i] > balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (balCorrect$bal[i] != balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
              }
            }
          }
          patScoSC$bal <- balCorrect$bal
        }
      }
      if(length(dropRows) > 0){
        ad <- data$assessmentDate[-dropRows]
        ad <- sapply(ad, function(x) ifelse(length(x) == 0, NA, x))
        ad <- as.Date(ad)
      }else{
        ad <- data$assessmentDate
      }
      scores <- data.frame(assessmentDate = ad, sc = patScoSC$sc,
                           bal = patScoSC$bal, uef = patScoSC$uef,
                           swl = patScoSC$swl, fim = patScoSC$fim,
                           scSE = patScoSC$scSE, balSE = patScoSC$balSE,
                           uefSE = patScoSC$uefSE, swlSE = patScoSC$swlSE,
                           fimSE = patScoSC$fimSE
      )
      if(length(dropRows) > 0){
        if(any(!is.na(ad))){
          naMat <- data.frame(scInd = rep(1, dim(scoreData2)[1]),
                              balInd = apply(scoreData[-dropRows, balIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                         )
                              ),
                              uefInd = apply(scoreData[-dropRows, uefIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                         )
                              ),
                              swlInd = apply(scoreData[-dropRows, swlIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                          )
                              ),
                              fimInd = apply(scoreData[-dropRows, fimIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                         )
                              )
          )
        }else{
          naMat <- NA
        }
      }else{
        naMat <- data.frame(scInd = rep(1, dim(scoreData2)[1]),
                            balInd = apply(scoreData[, balIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            uefInd = apply(scoreData[, uefIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            swlInd = apply(scoreData[, swlIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            fimInd = apply(scoreData[, fimIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            )
        )
      }
      scores[, 2:6] <- scores[, 2:6] * naMat
      scores[, 7:11] <- scores[, 7:11] * naMat
    }
    fimData <- scoreData[, which(colnames(scoreData) %in%
                                c('eating', 'grooming', 'bathing',
                                  'dressingUpper', 'dressingLower', 'toileting'
                                )
                          )
    ]
    if(marScoSwitch == 0){
      if(dim(scores)[1] > 1){
        scoCorrect <- scores[, 2:5]
        scoCorrect <- as.data.frame(apply(scoCorrect, 2, repeat.before))
        if(any(apply(scoCorrect, 2, function(x) all(is.na(x))))){
          scoCorrect <- scoCorrect[, -which(apply(scoCorrect, 2,
                                                 function(x) all(is.na(x))
                                            )
                                      )
          ]
        }
        fimRB <- apply(fimData, 2, repeat.before)
        if(!is.null(dim(scoCorrect))){
          for(i in 2:dim(scores)[1]){
            scs1 <- scoCorrect$sc[i]
            scs0 <- scoCorrect$sc[(i - 1)]
            others1 <- scoCorrect[i, 2:dim(scoCorrect)[2]]
            others0 <- scoCorrect[(i - 1), 2:dim(scoCorrect)[2]]
            fim1 <- fimRB[i, ]
            fim0 <- fimRB[(i - 1), ]
            if(scs1 < scs0){
              check1 <- all((others1 >= others0), na.rm = T)
              check2 <- all(!is.na(others0))
              check3 <- all((fim1 >= fim0), na.rm = T)
              check4 <- all(!is.na(fim0))
              scoCorrect$sc[i] <- ifelse(check1 && check2 && check3 && check4,
                                         scoCorrect$sc[(i - 1)], scoCorrect$sc[i]
              )
            }else if(scs1 > scs0){
              check1 <- all((others1 <= others0), na.rm = T)
              check2 <- all(!is.na(others0))
              check3 <- all((fim1 <= fim0), na.rm = T)
              check4 <- all(!is.na(fim0))
              scoCorrect$sc[i] <- ifelse(check1 && check2 && check3 && check4,
                                         scoCorrect$sc[(i - 1)], scoCorrect$sc[i]
              )
            }
          }
          scores$sc <- scoCorrect$sc
        }
      }
    }
    out <- list(scoreData, scores, fimData)
    out
  }
  
  ## The scoring function for the AQ-Mob. As with SC, there's additional
  ## markup within the function. It's mostly included to show where some small
  ## differences occur with respect to the mobility data.
  ### - data  = a data.frame containing AQ-Mob data
  ### - group = the mode of locomotion goal from the FIM for the patient being
  ###           scored
  scoFunMobFIM <- function(data, group){
    ## If the patient is expected to use a wheelchair after discharge...
    if(group == 1){
      ## Select relevant items
      scoreData <- data[, c(5:10, 22:25, 28, 30:32, 34)]
      ## Set column indices for the different assessment areas
      balIts <- c(1:6); wcIts <- c(7, 11, 15); xferIts <- c(13:14);
      cbpIts <- c(8:10); fimIts <- 12:15
      ## Replace "Does Not Occur" 88s in FIM data with NAs
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                   function(x) ifelse(x < 7 && !is.na(x),
                                                      x, NA
                                               )
      )
      ## Impute forward
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      ## Remove rows with all missing data
      dropRows <- which(apply(scoreData2, 1, function(x) all(is.na(x))) == T)
      if(length(dropRows) > 0){
        scoreData2 <- scoreData2[-dropRows, ]
        if(is.null(dim(scoreData2))){
          cn <- names(scoreData2)
          scoreData2 <- as.data.frame(matrix(scoreData2, nrow = 1))
          colnames(scoreData2) <- cn
        }
      }
      ## Score the data if there are any, else create a data frame full of NAs
      if(dim(scoreData2)[1] > 0){
        patScoMob <- as.data.frame(fscores(mobModWheel,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = wheelMeans,
                                           cov = mobLTCovWheel
                                   )
        )
        colnames(patScoMob) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                 'xfer', 'cbp', 'mobSE', 'balSE', 'wcSE',
                                 'xferSE', 'cbpSE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(1:6)]))){
            scoreData2_bal <- scoreData2
            scoreData2_bal[, c(7:15)] <- NA
            naPos <- which(apply(scoreData2_bal[, 1:6], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_bal[naPos, 1] <- 1
            }
            patScoMob_bal <- as.data.frame(
                               fscores(mobModWheel,
                                       response.pattern = scoreData2_bal,
                                       method = 'MAP',
                                       theta_lim = c(-6, 6),
                                       mean = wheelMeans,
                                       cov = mobLTCovWheel
                               )
            )
            colnames(patScoMob_bal) <- c(colnames(scoreData2), 'mob', 'bal',
                                         'wc', 'xfer', 'cbp', 'mobSE', 'balSE',
                                         'wcSE', 'xferSE', 'cbpSE'
            )
            patScoMob$bal <- patScoMob_bal$bal
            patScoMob$balSE <- patScoMob_bal$balSE
            if(length(naPos) > 0){
              patScoMob$bal[naPos] <- NA
              patScoMob$balSE[naPos] <- NA
            }
          }else{
            patScoMob$bal <- NA
            patScoMob$balSE <- NA
          }
          if(any(!is.na(scoreData2[, c(7, 11, 15)]))){
            scoreData2_wc <- scoreData2
            scoreData2_wc[, c(1:6, 8:10, 12:14)] <- NA
            naPos <- which(apply(scoreData2_wc[, c(7, 11, 15)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_wc[naPos, 7] <- 1
            }
            patScoMob_wc <- as.data.frame(
                               fscores(mobModWheel,
                                       response.pattern = scoreData2_wc,
                                       method = 'MAP',
                                       theta_lim = c(-6, 6),
                                       mean = wheelMeans,
                                       cov = mobLTCovWheel
                               )
            )
            colnames(patScoMob_wc) <- c(colnames(scoreData2), 'mob', 'bal',
                                        'wc', 'xfer', 'cbp', 'mobSE', 'balSE',
                                        'wcSE', 'xferSE', 'cbpSE'
            )
            patScoMob$wc <- patScoMob_wc$wc
            patScoMob$wcSE <- patScoMob_wc$wcSE
            if(length(naPos) > 0){
              patScoMob$wc[naPos] <- NA
              patScoMob$wcSE[naPos] <- NA
            }
          }else{
            patScoMob$wc <- NA
            patScoMob$wcSE <- NA
          }
          if(any(!is.na(scoreData2[, 13:14]))){
            scoreData2_xfer <- scoreData2
            scoreData2_xfer[, c(1:12, 15)] <- NA
            naPos <- which(apply(scoreData2_xfer[, 13:14], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_xfer[naPos, 13] <- 1
            }
            patScoMob_xfer <- as.data.frame(
                                fscores(mobModWheel,
                                        response.pattern = scoreData2_xfer,
                                        method = 'MAP',
                                        theta_lim = c(-6, 6),
                                        mean = wheelMeans,
                                        cov = mobLTCovWheel
                                )
            )
            colnames(patScoMob_xfer) <- c(colnames(scoreData2), 'mob', 'bal',
                                          'wc', 'xfer', 'cbp', 'mobSE',
                                          'balSE', 'wcSE', 'xferSE', 'cbpSE'
            )
            patScoMob$xfer <- patScoMob_xfer$xfer
            patScoMob$xferSE <- patScoMob_xfer$xferSE
            if(length(naPos) > 0){
              patScoMob$xfer[naPos] <- NA
              patScoMob$xferSE[naPos] <- NA
            }
          }else{
            patScoMob$xfer <- NA
            patScoMob$xferSE <- NA
          }
          if(any(!is.na(scoreData2[, 8:10]))){
            scoreData2_cbp <- scoreData2
            scoreData2_cbp[, c(1:7, 11:15)] <- NA
            naPos <- which(apply(scoreData2_cbp[, 8:10], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_cbp[naPos, 8] <- 1
            }
            patScoMob_cbp <- as.data.frame(
                               fscores(mobModWheel,
                                       response.pattern = scoreData2_cbp,
                                       method = 'MAP',
                                       theta_lim = c(-6, 6),
                                       mean = wheelMeans,
                                       cov = mobLTCovWheel
                                )
            )
            colnames(patScoMob_cbp) <- c(colnames(scoreData2), 'mob', 'bal',
                                         'wc', 'xfer', 'cbp', 'mobSE',
                                         'balSE', 'wcSE', 'xferSE', 'cbpSE'
            )
            patScoMob$cbp <- patScoMob_cbp$cbp
            patScoMob$cbpSE <- patScoMob_cbp$cbpSE
            if(length(naPos) > 0){
              patScoMob$cbp[naPos] <- NA
              patScoMob$cbpSE[naPos] <- NA
            }
          }else{
            patScoMob$cbp <- NA
            patScoMob$cbpSE <- NA
          }
        }
      }else{
        patScoMob <- as.data.frame(matrix(rep(NA,
                                              length(colnames(scoreData2)) + 10
                                          ), nrow = 1
                                   )
        )
        colnames(patScoMob) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                 'xfer', 'cbp', 'mobSE', 'balSE', 'wcSE',
                                 'xferSE', 'cbpSE'
        )
      }
      ## This is the same score correcting procedure from the SC section, but
      ## modified to apply to the mobility items
      if(marScoSwitch == 0){
        ## Define the assessment area being adjusted
        balCorrect <- patScoMob[, c(1:6, 17)]
        ## If there's actually balance data...
        if(nrow(balCorrect) > 1){
          ## From the second observation until the end of the score data.frame...
          for(i in 2:nrow(balCorrect)){
            ## Logical indicator for whether or not a score matches the previous
            ## one.
            diffScoCheck <- balCorrect$bal[i] != balCorrect$bal[(i - 1)]
            ## If the scores DO differ...
            if(diffScoCheck){
              ## If the data are all missing, but the scores differ, just pull
              ## forward the previous score (happens when the non-testlet
              ## model messes with the imputed "mean" that the fscores()
              ## function inserts when there's no data.
              if(all(is.na(balCorrect[i, 1:6])) &&
                 all(is.na(balCorrect[(i - 1), 1:6])))
              {
                balCorrect$bal[(i)] <- balCorrect$bal[(i - 1)]
              ## Otherwise, conduct a series of checks
              }else if(any(!is.na(balCorrect[i, 1:6])) &&
                       any(!is.na(balCorrect[(i - 1), 1:6])))
              {
                ## Identify which items were higher on the previous assessment
                ## date
                gtCheck <- which((balCorrect[i, 1:6] >=
                                  balCorrect[(i - 1), 1:6]) == F
                )
                ## Identify which scores were lower on the previous assessment
                ## date
                ltCheck <- which((balCorrect[i, 1:6] <=
                                  balCorrect[(i - 1), 1:6]) == F
                )
                ## Identify which items have stayed the same
                eqCheck <- which((balCorrect[i, 1:6] ==
                                  balCorrect[(i - 1), 1:6]) == F
                )
                ## And finally, check to see if more items were assessed on the
                ## previous date
                naCheck <- sum(is.na(balCorrect[i, 1:6])) <
                           sum(is.na(balCorrect[(i - 1), 1:6]))
                ## If the patient's balance data improved but their score is
                ## lower, just pull forward the previous score
                if(length(gtCheck) == 0 &&
                   (balCorrect$bal[i] < balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                ## If the patient's balance data got worse but their score is
                ## higher, just pull forward the previous score
                if(length(ltCheck) == 0 &&
                   (balCorrect$bal[i] > balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                ## If the data are identical but the score has changed for some
                ## reason (again, all of these discrepancies occur because
                ## mirtCAT hasn't implemented testlet models...), then pull
                ## forward the previous score
                if(length(eqCheck) == 0 &&
                   (balCorrect$bal[i] != balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
              }
            }
          }
          patScoMob$bal <- balCorrect$bal
        }
        wcCorrect <- patScoMob[, c(7, 11, 15, 18)]
        if(nrow(wcCorrect) > 1){
          for(i in 2:nrow(wcCorrect)){
            diffScoCheck <- wcCorrect$wc[i] != wcCorrect$wc[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(wcCorrect[i, 1:3])) &&
                 all(is.na(wcCorrect[(i - 1), 1:3])))
              {
                wcCorrect$wc[(i)] <- wcCorrect$wc[(i - 1)]
              }else if(any(!is.na(wcCorrect[i, 1:3])) &&
                       any(!is.na(wcCorrect[(i - 1), 1:3])))
              {
                gtCheck <- which((wcCorrect[i, 1:3] >=
                                  wcCorrect[(i - 1), 1:3]) == F
                )
                ltCheck <- which((wcCorrect[i, 1:3] <=
                                  wcCorrect[(i - 1), 1:3]) == F
                )
                eqCheck <- which((wcCorrect[i, 1:3] ==
                                  wcCorrect[(i - 1), 1:3]) == F
                )
                naCheck <- sum(is.na(wcCorrect[i, 1:3])) <
                           sum(is.na(wcCorrect[(i - 1), 1:3]))
                if(length(gtCheck) == 0 &&
                   (wcCorrect$wc[i] < wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (wcCorrect$wc[i] > wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (wcCorrect$wc[i] != wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
              }
            }
          }
          patScoMob$wc <- wcCorrect$wc
        }
        xferCorrect <- patScoMob[, c(13:14, 19)]
        if(nrow(xferCorrect) > 1){
          for(i in 2:nrow(xferCorrect)){
            diffScoCheck <- xferCorrect$xfer[i] != xferCorrect$xfer[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(xferCorrect[i, 1:2])) &&
                 all(is.na(xferCorrect[(i - 1), 1:2])))
              {
                xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
              }else if(any(!is.na(xferCorrect[i, 1:2])) &&
                       any(!is.na(xferCorrect[(i - 1), 1:2])))
              {
                gtCheck <- which((xferCorrect[i, 1:2] >=
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                ltCheck <- which((xferCorrect[i, 1:2] <=
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                eqCheck <- which((xferCorrect[i, 1:2] ==
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                naCheck <- sum(is.na(xferCorrect[i, 1:2])) <
                           sum(is.na(xferCorrect[(i - 1), 1:2]))
                if(length(gtCheck) == 0 &&
                   (xferCorrect$xfer[i] < xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (xferCorrect$xfer[i] > xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (xferCorrect$xfer[i] != xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
              }
            }
          }
          patScoMob$xfer <- xferCorrect$xfer
        }
        cbpCorrect <- patScoMob[, c(8:10, 20)]
        if(nrow(cbpCorrect) > 1){
          for(i in 2:nrow(cbpCorrect)){
            diffScoCheck <- cbpCorrect$cbp[i] != cbpCorrect$cbp[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(cbpCorrect[i, 1:3])) &&
                 all(is.na(cbpCorrect[(i - 1), 1:3])))
              {
                cbpCorrect$cbp[(i)] <- cbpCorrect$cbp[(i - 1)]
              }else if(any(!is.na(cbpCorrect[i, 1:3])) &&
                       any(!is.na(cbpCorrect[(i - 1), 1:3])))
              {
                gtCheck <- which((cbpCorrect[i, 1:3] >=
                                  cbpCorrect[(i - 1), 1:3]) == F
                )
                ltCheck <- which((cbpCorrect[i, 1:3] <=
                                  cbpCorrect[(i - 1), 1:3]) == F
                )
                eqCheck <- which((cbpCorrect[i, 1:3] ==
                                  cbpCorrect[(i - 1), 1:3]) == F
                )
                naCheck <- sum(is.na(cbpCorrect[i, 1:3])) <
                           sum(is.na(cbpCorrect[(i - 1), 1:3]))
                if(length(gtCheck) == 0 &&
                   (cbpCorrect$cbp[i] < cbpCorrect$cbp[(i - 1)]) &&
                   !naCheck)
                {
                  cbpCorrect$cbp[i] <- cbpCorrect$cbp[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (cbpCorrect$cbp[i] > cbpCorrect$cbp[(i - 1)]) &&
                   !naCheck)
                {
                  cbpCorrect$cbp[i] <- cbpCorrect$cbp[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (cbpCorrect$cbp[i] != cbpCorrect$cbp[(i - 1)]) &&
                   !naCheck)
                {
                  cbpCorrect$cbp[i] <- cbpCorrect$cbp[(i - 1)]
                }
              }
            }
          }
          patScoMob$cbp <- cbpCorrect$cbp
        }
      }
      if(length(dropRows) > 0){
        ad <- data$assessmentDate[-dropRows]
        ad <- sapply(ad, function(x) ifelse(length(x) == 0, NA, x))
        ad <- as.Date(ad)
      }else{
        ad <- data$assessmentDate
      }
      scores <- data.frame(assessmentDate = ad, mob = patScoMob$mob,
                           bal = patScoMob$bal, wc = patScoMob$wc,
                           xfer = patScoMob$xfer, cbp = patScoMob$cbp,
                           mobSE = patScoMob$mobSE, balSE = patScoMob$balSE,
                           wcSE = patScoMob$wcSE, xferSE = patScoMob$xferSE,
                           cbpSE = patScoMob$cbpSE
      )
      if(length(dropRows) > 0){
        if(any(!is.na(ad))){
          naMat <- data.frame(mobInd = rep(1, dim(scoreData)[1])[-dropRows],
                              balInd = apply(scoreData[-dropRows, balIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                         )
                              ),
                              wcInd = apply(scoreData[-dropRows, wcIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                                        )
                              ),
                              xferInd = apply(scoreData[-dropRows, xferIts], 1,
                                              function(x) ifelse(all(is.na(x)),
                                                                 NA, 1
                                                          )
                              ),
                              cbpInd = apply(scoreData[-dropRows, cbpIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                         )
                              )
          )
        }else{
          naMat <- NA
        }
      }else{
        naMat <- data.frame(mobInd = rep(1, dim(scoreData)[1]),
                            balInd = apply(scoreData[, balIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            wcInd = apply(scoreData[, wcIts], 1,
                                          function(x) ifelse(all(is.na(x)),
                                                             NA, 1
                                                      )
                            ),
                            xferInd = apply(scoreData[, xferIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                                        )
                            ),
                            cbpInd = apply(scoreData[, cbpIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            )
        )
      }
      scores[, 2:6] <- scores[, 2:6] * naMat
      scores[, 7:11] <- scores[, 7:11] * naMat
    }else if(group == 2){
      scoreData <- data[, c(5:16, 22, 26:35)]
      balIts <- c(1:12, 14:15, 17); wcIts <- c(13, 16, 22); xferIts <- 19:20
      fimIts <- 18:23
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                   function(x) ifelse(x < 7 && !is.na(x),
                                                     x, NA
                                               )
      )
      missCheck <- which(apply(scoreData, 1, function(x) all(is.na(x))))
      if(length(missCheck > 0)){
        scoreData <- scoreData[-missCheck, ]
        mobDate <- data$assessmentDate[-missCheck]
      }else{
        mobDate <- data$assessmentDate
      }
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      dropRows <- which(apply(scoreData2, 1, function(x) all(is.na(x))) == T)
      if(length(dropRows) > 0){
        scoreData2 <- scoreData2[-dropRows, ]
        if(is.null(dim(scoreData2))){
          cn <- names(scoreData2)
          scoreData2 <- as.data.frame(matrix(scoreData2, nrow = 1))
          colnames(scoreData2) <- cn
        }
      }
      if(dim(scoreData2)[1] > 0){
        patScoMob <- as.data.frame(fscores(mobModBoth,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = bothMeans,
                                           cov = mobLTCovBoth
                                   )
        )
        colnames(patScoMob) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                 'xfer', 'ld1', 'ld2', 'mobSE', 'balSE',
                                 'wcSE', 'xferSE', 'ld1SE', 'ld2SE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(1:12, 14:15, 17)]))){
            scoreData2_bal <- scoreData2
            scoreData2_bal[, c(13, 16, 18:23)] <- NA
            naPos <- which(apply(scoreData2_bal[, c(1:12, 14:15, 17)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_bal[naPos, 1] <- 1
            }
            patScoMob_bal <- as.data.frame(
                               fscores(mobModBoth,
                                       response.pattern = scoreData2_bal,
                                       method = 'MAP',
                                       theta_lim = c(-6, 6),
                                       mean = bothMeans,
                                       cov = mobLTCovBoth
                               )
            )
            colnames(patScoMob_bal) <- c(colnames(scoreData2), 'mob', 'bal',
                                         'wc', 'xfer', 'ld1', 'ld2', 'mobSE', 
                                         'balSE', 'wcSE', 'xferSE', 'ld1SE',
                                         'ld2SE'
            )
            patScoMob$bal <- patScoMob_bal$bal
            patScoMob$balSE <- patScoMob_bal$balSE
            if(length(naPos) > 0){
              patScoMob$bal[naPos] <- NA
              patScoMob$balSE[naPos] <- NA
            }
          }else{
            patScoMob$bal <- NA
            patScoMob$balSE <- NA
          }
          if(any(!is.na(scoreData2[, c(13, 16, 22)]))){
            scoreData2_wc <- scoreData2
            scoreData2_wc[, c(1:12, 14:15, 17:21, 23)] <- NA
            naPos <- which(apply(scoreData2_wc[, c(13, 16, 22)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_wc[naPos, 13] <- 1
            }
            patScoMob_wc <- as.data.frame(
                              fscores(mobModBoth,
                                      response.pattern = scoreData2_wc,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = bothMeans,
                                      cov = mobLTCovBoth
                              )
            )
            colnames(patScoMob_wc) <- c(colnames(scoreData2), 'mob', 'bal',
                                        'wc', 'xfer', 'ld1', 'ld2', 'mobSE', 
                                        'balSE', 'wcSE', 'xferSE', 'ld1SE',
                                        'ld2SE'
            )
            patScoMob$wc <- patScoMob_wc$wc
            patScoMob$wcSE <- patScoMob_wc$wcSE
            if(length(naPos) > 0){
              patScoMob$wc[naPos] <- NA
              patScoMob$wcSE[naPos] <- NA
            }
          }else{
            patScoMob$wc <- NA
            patScoMob$wcSE <- NA
          }
          if(any(!is.na(scoreData2[, 19:20]))){
            scoreData2_xfer <- scoreData2
            scoreData2_xfer[, c(1:18, 21:23)] <- NA
            naPos <- which(apply(scoreData2_xfer[, 19:20], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_xfer[naPos, 19] <- 1
            }
            patScoMob_xfer <- as.data.frame(
                                fscores(mobModBoth,
                                        response.pattern = scoreData2_xfer,
                                        method = 'MAP',
                                        theta_lim = c(-6, 6),
                                        mean = bothMeans,
                                        cov = mobLTCovBoth
                                )
            )
            colnames(patScoMob_xfer) <- c(colnames(scoreData2), 'mob', 'bal',
                                          'wc', 'xfer', 'ld1', 'ld2', 'mobSE',
                                          'balSE', 'wcSE', 'xferSE', 'ld1SE',
                                          'ld2SE'
            )
            patScoMob$xfer <- patScoMob_xfer$xfer
            patScoMob$xferSE <- patScoMob_xfer$xferSE
            if(length(naPos) > 0){
              patScoMob$xfer[naPos] <- NA
              patScoMob$xferSE[naPos] <- NA
            }
          }else{
            patScoMob$xfer <- NA
            patScoMob$xferSE <- NA
          }
        }
      }else{
        patScoMob <- as.data.frame(matrix(rep(NA,
                                              length(colnames(scoreData2)) + 12
                                          ),
                                          nrow = 1
                                   )
        )
        colnames(patScoMob) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                 'xfer', 'ld1', 'ld2', 'mobSE', 'balSE',
                                 'wcSE', 'xferSE', 'ld1SE', 'ld2SE'
        )
      }
      if(marScoSwitch == 0){
        balCorrect <- patScoMob[, c(balIts, 25)]
        if(nrow(balCorrect) > 1){
          for(i in 2:nrow(balCorrect)){
            diffScoCheck <- balCorrect$bal[i] != balCorrect$bal[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(balCorrect[i, 1:15])) &&
                 all(is.na(balCorrect[(i - 1), 1:15])))
              {
                balCorrect$bal[(i)] <- balCorrect$bal[(i - 1)]
              }else if(any(!is.na(balCorrect[i, 1:15])) &&
                       any(!is.na(balCorrect[(i - 1), 1:15])))
              {
                gtCheck <- which((balCorrect[i, 1:15] >=
                                  balCorrect[(i - 1), 1:15]) == F
                )
                ltCheck <- which((balCorrect[i, 1:15] <=
                                  balCorrect[(i - 1), 1:15]) == F
                )
                eqCheck <- which((balCorrect[i, 1:15] ==
                                  balCorrect[(i - 1), 1:15]) == F
                )
                naCheck <- sum(is.na(balCorrect[i, 1:15])) <
                           sum(is.na(balCorrect[(i - 1), 1:15]))
                if(length(gtCheck) == 0 &&
                   (balCorrect$bal[i] <balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (balCorrect$bal[i] > balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (balCorrect$bal[i] != balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
              }
            }
          }
          patScoMob$bal <- balCorrect$bal
        }
        wcCorrect <- patScoMob[, c(13, 16, 22, 26)]
        if(nrow(wcCorrect) > 1){
          for(i in 2:nrow(wcCorrect)){
            diffScoCheck <- wcCorrect$wc[i] != wcCorrect$wc[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(wcCorrect[i, 1:3])) &&
                 all(is.na(wcCorrect[(i - 1), 1:3])))
              {
                wcCorrect$wc[(i)] <- wcCorrect$wc[(i - 1)]
              }else if(any(!is.na(wcCorrect[i, 1:3])) &&
                       any(!is.na(wcCorrect[(i - 1), 1:3])))
              {
                gtCheck <- which((wcCorrect[i, 1:3] >=
                                  wcCorrect[(i - 1), 1:3]) == F
                )
                ltCheck <- which((wcCorrect[i, 1:3] <=
                                  wcCorrect[(i - 1), 1:3]) == F
                )
                eqCheck <- which((wcCorrect[i, 1:3] ==
                                  wcCorrect[(i - 1), 1:3]) == F
                )
                naCheck <- sum(is.na(wcCorrect[i, 1:3])) <
                           sum(is.na(wcCorrect[(i - 1), 1:3]))
                if(length(gtCheck) == 0 &&
                   (wcCorrect$wc[i] < wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (wcCorrect$wc[i] > wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (wcCorrect$wc[i] != wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
              }
            }
          }
          patScoMob$wc <- wcCorrect$wc
        }
        xferCorrect <- patScoMob[, c(19:20, 27)]
        if(nrow(xferCorrect) > 1){
          for(i in 2:nrow(xferCorrect)){
            diffScoCheck <- xferCorrect$xfer[i] != xferCorrect$xfer[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(xferCorrect[i, 1:2])) &&
                 all(is.na(xferCorrect[(i - 1), 1:2])))
              {
                xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
              }else if(any(!is.na(xferCorrect[i, 1:2])) &&
                       any(!is.na(xferCorrect[(i - 1), 1:2])))
              {
                gtCheck <- which((xferCorrect[i, 1:2] >=
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                ltCheck <- which((xferCorrect[i, 1:2] <=
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                eqCheck <- which((xferCorrect[i, 1:2] ==
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                naCheck <- sum(is.na(xferCorrect[i, 1:2])) <
                           sum(is.na(xferCorrect[(i - 1), 1:2]))
                if(length(gtCheck) == 0 &&
                   (xferCorrect$xfer[i] < xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (xferCorrect$xfer[i] > xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (xferCorrect$xfer[i] != xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
              }
            }
          }
          patScoMob$xfer <- xferCorrect$xfer
        }
      }
      if(length(dropRows) > 0){
        ad <- data$assessmentDate[-dropRows]
        ad <- sapply(ad, function(x) ifelse(length(x) == 0, NA, x))
        ad <- as.Date(ad)
      }else{
        ad <- mobDate
      }
      scores <- data.frame(assessmentDate = ad, mob = patScoMob$mob,
                           bal = patScoMob$bal, wc = patScoMob$wc,
                           xfer = patScoMob$xfer, mobSE = patScoMob$mobSE,
                           balSE = patScoMob$balSE, wcSE = patScoMob$wcSE,
                           xferSE = patScoMob$wcSE
      )
      if(length(dropRows) > 0){
        if(any(!is.na(ad))){
          naMat <- data.frame(mobImp = rep(1, dim(scoreData)[1]),
                              balInd = apply(scoreData[-dropRows, balIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                         )
                              ),
                              wcInd = apply(scoreData[-dropRows, wcIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                                        )
                              ),
                              xferInd = apply(scoreData[-dropRows, xferIts], 1,
                                              function(x) ifelse(all(is.na(x)),
                                                                 NA, 1
                                                          )
                              )
          )
        }else{
          naMat <- NA
        }
      }else{
        naMat <- data.frame(mobImp = rep(1, dim(scoreData)[1]),
                            balInd = apply(scoreData[, balIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            wcInd = apply(scoreData[, wcIts], 1,
                                          function(x) ifelse(all(is.na(x)),
                                                             NA, 1
                                                      )
                            ),
                            xferInd = apply(scoreData[, xferIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                                        )
                            )
        )
      }
      scores[, 2:5] <- scores[, 2:5] * naMat
      scores[, 6:9] <- scores[, 6:9] * naMat
    }else if(group == 3){
      scoreData <- data[, c(11:21, 26:35)]
      balIts <- c(1:13, 15); wcIts <- c(14, 20); xferIts <- 17:18;
      fimIts <- 16:21
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                   function(x) ifelse(x < 7 && !is.na(x),
                                                      x, NA
                                               )
      )
      missCheck <- which(apply(scoreData, 1, function(x) all(is.na(x))))
      if(length(missCheck > 0)){
        scoreData <- scoreData[-missCheck, ]
        mobDate <- data$assessmentDate[-missCheck]
      }else{
        mobDate <- data$assessmentDate
      }
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      dropRows <- which(apply(scoreData2, 1, function(x) all(is.na(x))) == T)
      if(length(dropRows) > 0){
        scoreData2 <- scoreData2[-dropRows, ]
        if(is.null(dim(scoreData2))){
          cn <- names(scoreData2)
          scoreData2 <- as.data.frame(matrix(scoreData2, nrow = 1))
          colnames(scoreData2) <- cn
        }
      }
      if(dim(scoreData2)[1] > 0){
        patScoMob <- as.data.frame(fscores(mobModWalk,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = walkMeans,
                                           cov = mobLTCovWalk
                                    )
        )
        colnames(patScoMob) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                 'xfer', 'ld1', 'ld2', 'mobSE', 'balSE',
                                 'wcSE', 'xferSE', 'ld1SE', 'ld2SE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(1:13, 15)]))){
            scoreData2_bal <- scoreData2
            scoreData2_bal[, c(14, 16:21)] <- NA
            naPos <- which(apply(scoreData2_bal[, c(1:13, 15)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_bal[naPos, 1] <- 1
            }
            patScoMob_bal <- as.data.frame(
                               fscores(mobModWalk,
                                       response.pattern = scoreData2_bal,
                                       method = 'MAP',
                                       theta_lim = c(-6, 6),
                                       mean = walkMeans,
                                       cov = mobLTCovWalk
                               )
            )
            colnames(patScoMob_bal) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                         'xfer', 'ld1', 'ld2', 'mobSE', 'balSE',
                                         'wcSE', 'xferSE', 'ld1SE', 'ld2SE'
            )
            patScoMob$bal <- patScoMob_bal$bal
            patScoMob$balSE <- patScoMob_bal$balSE
            if(length(naPos) > 0){
              patScoMob$bal[naPos] <- NA
              patScoMob$balSE[naPos] <- NA
            }
          }else{
            patScoMob$bal <- NA
            patScoMob$balSE <- NA
          }
          if(any(!is.na(scoreData2[, c(14, 20)]))){
            scoreData2_wc <- scoreData2
            scoreData2_wc[, c(1:13, 15:19, 21)] <- NA
            naPos <- which(apply(scoreData2_wc[, c(14, 20)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_wc[naPos, 14] <- 1
            }
            patScoMob_wc <- as.data.frame(
                              fscores(mobModWalk,
                                      response.pattern = scoreData2_wc,
                                      method = 'MAP',
                                      theta_lim = c(-6, 6),
                                      mean = walkMeans,
                                      cov = mobLTCovWalk
                              )
            )
            colnames(patScoMob_wc) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                        'xfer', 'ld1', 'ld2', 'mobSE', 'balSE',
                                        'wcSE', 'xferSE', 'ld1SE', 'ld2SE'
            )
            patScoMob$wc <- patScoMob_wc$wc
            patScoMob$wcSE <- patScoMob_wc$wcSE
            if(length(naPos) > 0){
              patScoMob$wc[naPos] <- NA
              patScoMob$wcSE[naPos] <- NA
            }
          }else{
            patScoMob$wc <- NA
            patScoMob$wcSE <- NA
          }
          if(any(!is.na(scoreData2[, 17:18]))){
            scoreData2_xfer <- scoreData2
            scoreData2_xfer[, c(1:16, 19:21)] <- NA
            naPos <- which(apply(scoreData2_xfer[, 17:18], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_xfer[naPos, 17] <- 1
            }
            patScoMob_xfer <- as.data.frame(
                                fscores(mobModWalk,
                                        response.pattern = scoreData2_xfer,
                                        method = 'MAP',
                                        theta_lim = c(-6, 6),
                                        mean = walkMeans,
                                        cov = mobLTCovWalk
                                )
            )
            colnames(patScoMob_xfer) <- c(colnames(scoreData2), 'mob', 'bal',
                                          'wc', 'xfer', 'ld1', 'ld2', 'mobSE',
                                          'balSE', 'wcSE', 'xferSE', 'ld1SE',
                                          'ld2SE'
            )
            patScoMob$xfer <- patScoMob_xfer$xfer
            patScoMob$xferSE <- patScoMob_xfer$xferSE
            if(length(naPos) > 0){
              patScoMob$xfer[naPos] <- NA
              patScoMob$xferSE[naPos] <- NA
            }
          }else{
            patScoMob$xfer <- NA
            patScoMob$xferSE <- NA
          }
        }
      }else{
        patScoMob <- as.data.frame(matrix(rep(NA,
                                              length(colnames(scoreData2)) + 12
                                          ),
                                          nrow = 1
                                   )
        )
        colnames(patScoMob) <- c(colnames(scoreData2), 'mob', 'bal', 'wc',
                                 'xfer', 'ld1', 'ld2', 'mobSE', 'balSE',
                                 'wcSE', 'xferSE', 'ld1SE', 'ld2SE'
        )
      }
      if(marScoSwitch == 0){
        balCorrect <- patScoMob[, c(balIts, 23)]
        if(nrow(balCorrect) > 1){
          for(i in 2:nrow(balCorrect)){
            diffScoCheck <- balCorrect$bal[i] != balCorrect$bal[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(balCorrect[i, 1:14])) &&
                 all(is.na(balCorrect[(i - 1), 1:14])))
              {
                balCorrect$bal[(i)] <- balCorrect$bal[(i - 1)]
              }else if(any(!is.na(balCorrect[i, 1:14])) &&
                       any(!is.na(balCorrect[(i - 1), 1:14])))
              {
                gtCheck <- which((balCorrect[i, 1:14] >=
                                  balCorrect[(i - 1), 1:14]) == F
                )
                ltCheck <- which((balCorrect[i, 1:14] <=
                                  balCorrect[(i - 1), 1:14]) == F
                )
                eqCheck <- which((balCorrect[i, 1:14] ==
                                  balCorrect[(i - 1), 1:14]) == F
                )
                naCheck <- sum(is.na(balCorrect[i, 1:14])) <
                           sum(is.na(balCorrect[(i - 1), 1:14]))
                if(length(gtCheck) == 0 &&
                   (balCorrect$bal[i] < balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (balCorrect$bal[i] > balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (balCorrect$bal[i] != balCorrect$bal[(i - 1)]) &&
                   !naCheck)
                {
                  balCorrect$bal[i] <- balCorrect$bal[(i - 1)]
                }
              }
            }
          }
          patScoMob$bal <- balCorrect$bal
        }
        wcCorrect <- patScoMob[, c(14, 20, 24)]
        if(nrow(wcCorrect) > 1){
          for(i in 2:nrow(wcCorrect)){
            diffScoCheck <- wcCorrect$wc[i] != wcCorrect$wc[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(wcCorrect[i, 1:2])) &&
                 all(is.na(wcCorrect[(i - 1), 1:2])))
              {
                wcCorrect$wc[(i)] <- wcCorrect$wc[(i - 1)]
              }else if(any(!is.na(wcCorrect[i, 1:2])) &&
                       any(!is.na(wcCorrect[(i - 1), 1:2])))
              {
                gtCheck <- which((wcCorrect[i, 1:2] >=
                                  wcCorrect[(i - 1), 1:2]) == F
                )
                ltCheck <- which((wcCorrect[i, 1:2] <=
                                  wcCorrect[(i - 1), 1:2]) == F
                )
                eqCheck <- which((wcCorrect[i, 1:2] ==
                                  wcCorrect[(i - 1), 1:2]) == F
                )
                naCheck <- sum(is.na(wcCorrect[i, 1:2])) <
                           sum(is.na(wcCorrect[(i - 1), 1:2]))
                if(length(gtCheck) == 0 &&
                   (wcCorrect$wc[i] < wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (wcCorrect$wc[i] > wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (wcCorrect$wc[i] != wcCorrect$wc[(i - 1)]) &&
                   !naCheck)
                {
                  wcCorrect$wc[i] <- wcCorrect$wc[(i - 1)]
                }
              }
            }
          }
          patScoMob$wc <- wcCorrect$wc
        }
        xferCorrect <- patScoMob[, c(17:18, 25)]
        if(nrow(xferCorrect) > 1){
          for(i in 2:nrow(xferCorrect)){
            diffScoCheck <- xferCorrect$xfer[i] != xferCorrect$xfer[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(xferCorrect[i, 1:2])) &&
                 all(is.na(xferCorrect[(i - 1), 1:2])))
              {
                xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
              }else if(any(!is.na(xferCorrect[i, 1:2])) &&
                       any(!is.na(xferCorrect[(i - 1), 1:2])))
              {
                gtCheck <- which((xferCorrect[i, 1:2] >=
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                ltCheck <- which((xferCorrect[i, 1:2] <=
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                eqCheck <- which((xferCorrect[i, 1:2] ==
                                  xferCorrect[(i - 1), 1:2]) == F
                )
                naCheck <- sum(is.na(xferCorrect[i, 1:2])) <
                           sum(is.na(xferCorrect[(i - 1), 1:2]))
                if(length(gtCheck) == 0 &&
                   (xferCorrect$xfer[i] < xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (xferCorrect$xfer[i] > xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (xferCorrect$xfer[i] != xferCorrect$xfer[(i - 1)]) &&
                   !naCheck)
                {
                  xferCorrect$xfer[i] <- xferCorrect$xfer[(i - 1)]
                }
              }
            }
          }
          patScoMob$xfer <- xferCorrect$xfer
        }
      }
      if(length(dropRows) > 0){
        ad <- data$assessmentDate[-dropRows]
        ad <- sapply(ad, function(x) ifelse(length(x) == 0, NA, x))
        ad <- as.Date(ad)
      }
      if(length(missCheck) > 0){
        ad <- data$assessmentDate[-missCheck]
        ad <- sapply(ad, function(x) ifelse(length(x) == 0, NA, x))
        ad <- as.Date(ad)
      }
      if(length(dropRows) == 0 && length(missCheck) == 0){
        ad <- data$assessmentDate
      }
      scores <- data.frame(assessmentDate = ad, mob = patScoMob$mob,
                           bal = patScoMob$bal, wc = patScoMob$wc,
                           xfer = patScoMob$xfer, mobSE = patScoMob$mobSE,
                           balSE = patScoMob$balSE, wcSE = patScoMob$wcSE,
                           xferSE = patScoMob$wcSE
      )
      if(length(dropRows) > 0){
        if(any(!is.na(ad))){
          naMat <- data.frame(mobImp = rep(1, dim(scoreData)[1]),
                              balInd = apply(scoreData[-dropRows, balIts], 1,
                                             function(x) ifelse(all(is.na(x)),
                                                                NA, 1
                                                         )
                              ),
                              wcInd = apply(scoreData[-dropRows, wcIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                            )
                              ),
                              xferInd = apply(scoreData[-dropRows, xferIts], 1,
                                              function(x) ifelse(all(is.na(x)),
                                                                 NA, 1
                                                          )
                              )
          )
        }else{
          naMat <- NA
        }
      }else{
        naMat <- data.frame(mobImp = rep(1, dim(scoreData)[1]),
                            balInd = apply(scoreData[, balIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            wcInd = apply(scoreData[, wcIts], 1,
                                          function(x) ifelse(all(is.na(x)),
                                                             NA, 1
                                                      )
                            ),
                            xferInd = apply(scoreData[, xferIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                                        )
                            )
        )
      }
      scores[, 2:5] <- scores[, 2:5] * naMat
      scores[, 6:9] <- scores[, 6:9] * naMat
    }
    fimData <- scoreData[, which(colnames(scoreData) %in%
                                 c('bedChairTransfer', 'tubShowerTransfer',
                                   'toiletTransfer', 'locomotionWalk',
                                   'locomotionWheelchair', 'locomotionStairs'
                                 )
                           )
    ]
    if(marScoSwitch == 0){
      if(dim(scores)[1] > 1){
        if(group == 1){
          scoCorrect <- scores[, 2:6]
        }else if(group %in% c(2, 3)){
          scoCorrect <- scores[, 2:5]
        }
        scoCorrect <- as.data.frame(apply(scoCorrect, 2, repeat.before))
        if(any(apply(scoCorrect, 2, function(x) all(is.na(x))))){
          scoCorrect <- scoCorrect[, -which(apply(scoCorrect, 2,
                                                  function(x) all(is.na(x)))
                                      )
          ]
        }
        fimRB <- apply(fimData, 2, repeat.before)
        if(!is.null(dim(scoCorrect))){
          for(i in 2:dim(scores)[1]){
            mobs1 <- scoCorrect$mob[i]
            mobs0 <- scoCorrect$mob[(i - 1)]
            others1 <- scoCorrect[i, 2:dim(scoCorrect)[2]]
            others0 <- scoCorrect[(i - 1), 2:dim(scoCorrect)[2]]
            fim1 <- fimRB[i, ]
            fim0 <- fimRB[(i - 1), ]
            if(mobs1 < mobs0){
              check1 <- all((others1 >= others0), na.rm = T)
              check2 <- all(!is.na(others0))
              check3 <- all((fim1 >=fim0), na.rm = T)
              check4 <- all(!is.na(fim0))
              scoCorrect$mob[i] <- ifelse(check1 && check2 && check3 && check4,
                                          scoCorrect$mob[(i - 1)],
                                          scoCorrect$mob[i]
              )
            }else if(mobs1 <= mobs0){
              check1 <- all((others1 <= others0), na.rm = T)
              check2 <- all(!is.na(others0))
              check3 <- all((fim1 <= fim0), na.rm = T)
              check4 <- all(!is.na(fim0))
              scoCorrect$mob[i] <- ifelse(check1 && check2 && check3 && check4,
                                          scoCorrect$mob[(i - 1)],
                                          scoCorrect$mob[i]
              )
            }
          }
          scores$mob <- scoCorrect$mob
        }
      }
    }
    out <- list(scoreData, scores, fimData)
  }
  
  ## The scoring function for the AQ-Cog. More markup included within the
  ## function. It's notably different than the SC and Mob scoring functions.
  ## That's because it's adapted from a slightly older version of the
  ## dashboard.
  ### - data  = a data.frame contaoining AQ-Cog data
  ### - group = the most severe cognitive diagnosis from the SLP eval form
  scoFunCogFIM <- function(data, group){
    ## If the patient has aphasia...
    ## These if/elses with respect to diagnosis all work more or less the
    ## same as they did in the other domains. Divergences from the process
    if(group == 1){
      scoreData <- data[, c(22, 24:43)]
      fimIts <- 17:21; comIts <- c(2:7, 11:13, 16); wcomIts <- 8:10
      compIts <- 14:15
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                   function(x) ifelse(x < 7 && !is.na(x),
                                                      x, NA
                                               )
      )
      dropRows <- which(apply(scoreData, 1, function(x) all(is.na(x))))
      if(length(dropRows) > 0){
        scoreData <- scoreData[-dropRows, ]
      }else{
        dropRows <- NA
      }
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      if(dim(scoreData2)[1] > 0){
        patScoCog <- as.data.frame(fscores(cogModAph,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = aphMeans,
                                           cov = cogLTCovAph
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'no1',
                                 'no2', 'com', 'wcom', 'comp', 'cogSE',
                                 'fimSE', 'no1SE', 'no2SE', 'comSE', 'wcomSE',
                                 'compSE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(2:8, 11:13, 16)]))){
            scoreData2_com <- scoreData2
            scoreData2_com[, c(1, 9:10, 14:15, 17:21)] <- NA
            naPos <- which(apply(scoreData2_com[, c(2:8, 11:13, 16)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_com[naPos, 2] <- 1
            }
            patScoCog_com <- as.data.frame(fscores(cogModAph,
                                           response.pattern = scoreData2_com,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = aphMeans,
                                           cov = cogLTCovAph
                             )
            )
            colnames(patScoCog_com) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'no1', 'no2', 'com', 'wcom', 'comp',
                                         'cogSE', 'fimSE', 'no1SE', 'no2SE',
                                         'comSE', 'wcomSE', 'compSE'
            )
            patScoCog$com <- patScoCog_com$com
            patScoCog$comSE <- patScoCog_com$comSE
            if(length(naPos) > 0){
              patScoCog$com[naPos] <- NA
              patScoCog$comSE[naPos] <- NA
            }
          }else{
            patScoCog$com <- NA
            patScoCog$comSE <- NA
          }
          if(any(!is.na(scoreData2[, 8:10]))){
            scoreData2_wcom <- scoreData2
            scoreData2_wcom[, c(1:7, 11:21)] <- NA
            naPos <- which(apply(scoreData2_wcom[, 8:10], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_wcom[naPos, 8] <- 1
            }
            patScoCog_wcom <- as.data.frame(fscores(cogModAph,
                                            response.pattern = scoreData2_wcom,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = aphMeans,
                                            cov = cogLTCovAph
                              )
            )
            colnames(patScoCog_wcom) <- c(colnames(scoreData2), 'cog', 'fim',
                                          'no1', 'no2', 'com', 'wcom', 'comp',
                                          'cogSE', 'fimSE', 'no1SE', 'no2SE',
                                          'comSE', 'wcomSE', 'compSE'
            )
            patScoCog$wcom <- patScoCog_wcom$wcom
            patScoCog$wcomSE <- patScoCog_com$wcomSE
            if(length(naPos) > 0){
              patScoCog$wcom[naPos] <- NA
              patScoCog$wcomSE[naPos] <- NA
            }
          }else{
            patScoCog$wcom <- NA
            patScoCog$wcomSE <- NA
          }
          if(any(!is.na(scoreData2[, 14:15]))){
            scoreData2_comp <- scoreData2
            scoreData2_comp[, c(1:13, 16:21)] <- NA
            naPos <- which(apply(scoreData2_comp[, 14:15], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_comp[naPos, 14] <- 1
            }
            patScoCog_comp <- as.data.frame(fscores(cogModAph,
                                            response.pattern = scoreData2_comp,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = aphMeans,
                                            cov = cogLTCovAph
                              )
            )
            colnames(patScoCog_comp) <- c(colnames(scoreData2), 'cog', 'fim',
                                          'no1', 'no2', 'com', 'wcom', 'comp',
                                          'cogSE', 'fimSE', 'no1SE', 'no2SE',
                                          'comSE', 'wcomSE', 'compSE'
            )
            patScoCog$comp <- patScoCog_comp$comp
            patScoCog$compSE <- patScoCog_com$compSE
            if(length(naPos) > 0){
              patScoCog$comp[naPos] <- NA
              patScoCog$compSE[naPos] <- NA
            }
          }else{
            patScoCog$comp <- NA
            patScoCog$compSE <- NA
          }
        }
      }else{
        patScoCog <- as.data.frame(matrix(rep(NA,
                                              length(colnames(scoreData2)) + 14
                                          ),
                                          nrow = 1
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'no1',
                                 'no2', 'com', 'wcom', 'comp', 'cogSE',
                                 'fimSE', 'no1SE', 'no2SE', 'comSE', 'wcomSE',
                                 'compSE'
        )
      }
      if(marScoSwitch == 0){
        comCorrect <- patScoCog[, c(comIts, 26)]
        if(nrow(comCorrect) > 1){
          for(i in 2:nrow(comCorrect)){
            diffScoCheck <- comCorrect$com[i] != comCorrect$com[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(comCorrect[i, 1:10])) &&
                 all(is.na(comCorrect[(i - 1), 1:10])))
              {
                comCorrect$com[(i)] <- comCorrect$com[(i - 1)]
              }else if(any(!is.na(comCorrect[i, 1:10])) &&
                       any(!is.na(comCorrect[(i - 1), 1:10])))
              {
                gtCheck <- which((comCorrect[i, 1:10] >=
                                  comCorrect[(i - 1), 1:10]) == F
                )
                ltCheck <- which((comCorrect[i, 1:10] <=
                                  comCorrect[(i - 1), 1:10]) == F
                )
                eqCheck <- which((comCorrect[i, 1:10] ==
                                  comCorrect[(i - 1), 1:10]) == F
                )
                naCheck <- sum(is.na(comCorrect[i, 1:10])) <
                           sum(is.na(comCorrect[(i - 1), 1:10]))
                if(length(gtCheck) == 0 &&
                   (comCorrect$com[i] < comCorrect$com[(i - 1)]) &&
                   !naCheck)
                {
                  comCorrect$com[i] <- comCorrect$com[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (comCorrect$com[i] > comCorrect$com[(i - 1)]) &&
                   !naCheck)
                {
                  comCorrect$com[i] <- comCorrect$com[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (comCorrect$com[i] != comCorrect$com[(i - 1)]) &&
                   !naCheck)
                {
                  comCorrect$com[i] <- comCorrect$com[(i - 1)]
                }
              }
            }
          }
          patScoCog$com <- comCorrect$com
        }
        wcomCorrect <- patScoCog[, c(wcomIts, 27)]
        if(nrow(wcomCorrect) > 1){
          for(i in 2:nrow(wcomCorrect)){
            diffScoCheck <- wcomCorrect$wcom[i] != wcomCorrect$wcom[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(wcomCorrect[i, 1:3])) &&
                 all(is.na(wcomCorrect[(i - 1), 1:3])))
              {
                wcomCorrect$wcom[(i)] <- wcomCorrect$wcom[(i - 1)]
              }else if(any(!is.na(wcomCorrect[i, 1:3])) &&
                       any(!is.na(wcomCorrect[(i - 1), 1:3])))
              {
                gtCheck <- which((wcomCorrect[i, 1:3] >=
                                  wcomCorrect[(i - 1), 1:3]) == F
                )
                ltCheck <- which((wcomCorrect[i, 1:3] <=
                                  wcomCorrect[(i - 1), 1:3]) == F
                )
                eqCheck <- which((wcomCorrect[i, 1:3] ==
                                  wcomCorrect[(i - 1), 1:3]) == F
                )
                naCheck <- sum(is.na(wcomCorrect[i, 1:3])) <
                           sum(is.na(wcomCorrect[(i - 1), 1:3]))
                if(length(gtCheck) == 0 &&
                   (wcomCorrect$wcom[i] < wcomCorrect$wcom[(i - 1)]) &&
                   !naCheck)
                {
                  wcomCorrect$wcom[i] <- wcomCorrect$wcom[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (wcomCorrect$wcom[i] > wcomCorrect$wcom[(i - 1)]) &&
                   !naCheck)
                {
                  wcomCorrect$wcom[i] <- wcomCorrect$wcom[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (wcomCorrect$wcom[i] != wcomCorrect$wcom[(i - 1)]) &&
                   !naCheck)
                {
                  wcomCorrect$wcom[i] <- wcomCorrect$wcom[(i - 1)]
                }
              }
            }
          }
          patScoCog$wcom <- wcomCorrect$wcom
        }
        compCorrect <- patScoCog[, c(compIts, 28)]
        if(nrow(compCorrect) > 1){
          for(i in 2:nrow(compCorrect)){
            diffScoCheck <- compCorrect$comp[i] != compCorrect$comp[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(compCorrect[i, 1:2])) &&
                 all(is.na(compCorrect[(i - 1), 1:2])))
              {
                compCorrect$comp[(i)] <- compCorrect$comp[(i - 1)]
              }else if(any(!is.na(compCorrect[i, 1:2])) &&
                       any(!is.na(compCorrect[(i - 1), 1:2])))
              {
                gtCheck <- which((compCorrect[i, 1:2] >=
                                  compCorrect[(i - 1), 1:2]) == F
                )
                ltCheck <- which((compCorrect[i, 1:2] <=
                                  compCorrect[(i - 1), 1:2]) == F
                )
                eqCheck <- which((compCorrect[i, 1:2] ==
                                  compCorrect[(i - 1), 1:2]) == F
                )
                naCheck <- sum(is.na(compCorrect[i, 1:2])) <
                           sum(is.na(compCorrect[(i - 1), 1:2]))
                if(length(gtCheck) == 0 &&
                   (compCorrect$comp[i] < compCorrect$comp[(i - 1)])&&
                   !naCheck)
                {
                  compCorrect$comp[i] <- compCorrect$comp[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (compCorrect$comp[i] > compCorrect$comp[(i - 1)]) &&
                   !naCheck)
                {
                  compCorrect$comp[i] <- compCorrect$comp[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (compCorrect$comp[i] != compCorrect$comp[(i - 1)]) &&
                   !naCheck)
                {
                  compCorrect$comp[i] <- compCorrect$comp[(i - 1)]
                }
              }
            }
          }
          patScoCog$comp <- compCorrect$comp
        }
      }
      if(length(dropRows) > 0 && !is.na(dropRows)){
        ad <- data$assessmentDate[-dropRows]
        if(length(ad) > 0){
          ad <- as.Date(sapply(ad, function(x) ifelse(x == 0, NA, x)))
        }else if(length(ad) == 0){
          ad <- NA
        }
      }else{
        ad <- data$assessmentDate
      }
      if(all(!is.na(dropRows))){
        scores <- data.frame(assessmentDate = ad, cog = patScoCog$cog,
                             com = patScoCog$com, wcom = patScoCog$wcom,
                             comp = patScoCog$comp, fim = patScoCog$fim,
                             cogSE = patScoCog$cogSE, comSE = patScoCog$comSE,
                             wcomSE = patScoCog$wcomSE,
                             compSE = patScoCog$compSE, fimSE = patScoCog$fimSE
        )
      }else{
        scores <- data.frame(assessmentDate = ad, cog = patScoCog$cog,
                             com = patScoCog$com, wcom = patScoCog$wcom,
                             comp = patScoCog$comp, fim = patScoCog$fim,
                             cogSE = patScoCog$cogSE, comSE = patScoCog$comSE,
                             wcomSE = patScoCog$wcomSE,
                             compSE = patScoCog$compSE, fimSE = patScoCog$fimSE
        )
      }
      if(any(!is.na(ad))){
        naMat <- data.frame(cogInd = rep(1, dim(scoreData)[1]),
                            comInd = apply(scoreData[, comIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            wcomInd = apply(scoreData[, wcomIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                                        )
                            ),
                            compInd = apply(scoreData[, compIts], 1,
                                            function(x) ifelse(all(is.na(x)),
                                                               NA, 1
                                                        )
                            ),
                            fimInd = apply(scoreData[, fimIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            )
        )
      }else{
        naMat <- NA
      }
      scores[, 2:6] <- scores[, 2:6] * naMat
      scores[, 7:11] <- scores[, 7:11] * naMat
    }else if(group == 2){
      scoreData <- data[, c(5:10, 17:23, 39:43)]
      fimIts <- 14:18; speIts <- 10:13; memIts <- 1:9
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                   function(x) ifelse(x < 7 && !is.na(x),
                                                      x, NA
                                               )
      )
      dropRows <- which(apply(scoreData, 1, function(x) all(is.na(x))))
      if(length(dropRows) > 0){
        scoreData <- scoreData[-dropRows, ]
      }else{
        dropRows <- NA
      }
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      if(dim(scoreData)[1] > 0){
        patScoCog <- as.data.frame(fscores(cogModCCD,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = ccdMeans,
                                           cov = cogLTCovCCD
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'spe',
                                 'mem', 'cogSE', 'fimSE', 'speSE', 'memSE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, 10:13]))){
            scoreData2_spe <- scoreData2
            scoreData2_spe[, c(1:9, 14:18)] <- NA
            naPos <- which(apply(scoreData2_spe[, 10:13], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_spe[naPos, 10] <- 1
            }
            patScoCog_spe <- as.data.frame(fscores(cogModCCD,
                                            response.pattern = scoreData2_spe,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = ccdMeans,
                                            cov = cogLTCovCCD
                              )
            )
            colnames(patScoCog_spe) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'spe', 'mem', 'cogSE', 'fimSE',
                                         'speSE', 'memSE'
            )
            patScoCog$spe <- patScoCog_spe$spe
            patScoCog$speSE <- patScoCog_spe$speSE
            if(length(naPos) > 0){
              patScoCog$spe[naPos] <- NA
              patScoCog$speSE[naPos] <- NA
            }
          }else{
            patScoCog$spe <- NA
            patScoCog$speSE <- NA
          }
          if(any(!is.na(scoreData2[, 1:9]))){
            scoreData2_mem <- scoreData2
            scoreData2_mem[, 10:18] <- NA
            naPos <- which(apply(scoreData2_mem[, 1:9], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_mem[naPos, 1] <- 1
            }
            patScoCog_mem <- as.data.frame(fscores(cogModCCD,
                                            response.pattern = scoreData2_mem,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = ccdMeans,
                                            cov = cogLTCovCCD
                              )
            )
            colnames(patScoCog_mem) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'spe', 'mem', 'cogSE', 'fimSE',
                                         'speSE', 'memSE'
            )
            patScoCog$mem <- patScoCog_mem$mem
            patScoCog$memSE <- patScoCog_mem$memSE
            if(length(naPos) > 0){
              patScoCog$mem[naPos] <- NA
              patScoCog$memSE[naPos] <- NA
            }
          }else{
            patScoCog$mem <- NA
            patScoCog$memSE <- NA
          }
        }
      }else{
        patScoCog <- as.data.frame(matrix(rep(NA,
                                              length(colnames(scoreData2)) + 8
                                          ),
                                          nrow = 1
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'spe',
                                 'mem', 'cogSE', 'fimSE', 'speSE', 'memSE'
        )
      }
      if(marScoSwitch == 0){
        speCorrect <- patScoCog[, c(speIts, 21)]
        if(nrow(speCorrect) > 1){
          for(i in 2:nrow(speCorrect)){
            diffScoCheck <- speCorrect$spe[i] != speCorrect$spe[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(speCorrect[i, 1:4])) &&
                 all(is.na(speCorrect[(i - 1), 1:4])))
              {
                speCorrect$spe[(i)] <- speCorrect$spe[(i - 1)]
              }else if(any(!is.na(speCorrect[i, 1:4])) &&
                       any(!is.na(speCorrect[(i - 1), 1:4])))
              {
                gtCheck <- which((speCorrect[i, 1:4] >=
                                  speCorrect[(i - 1), 1:4]) == F
                )
                ltCheck <- which((speCorrect[i, 1:4] <=
                                  speCorrect[(i - 1), 1:4]) == F
                )
                eqCheck <- which((speCorrect[i, 1:4] ==
                                  speCorrect[(i - 1), 1:4]) == F
                )
                naCheck <- sum(is.na(speCorrect[i, 1:4])) <
                           sum(is.na(speCorrect[(i - 1), 1:4]))
                if(length(gtCheck) == 0 &&
                   (speCorrect$spe[i] < speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (speCorrect$spe[i] > speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (speCorrect$spe[i] != speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
              }
            }
          }
          patScoCog$spe <- speCorrect$spe
        }
        memCorrect <- patScoCog[, c(memIts, 22)]
        if(nrow(memCorrect) > 1){
          for(i in 2:nrow(memCorrect)){
            diffScoCheck <- memCorrect$mem[i] != memCorrect$mem[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(memCorrect[i, 1:9])) &&
                 all(is.na(memCorrect[(i - 1), 1:9])))
              {
                memCorrect$mem[(i)] <- memCorrect$mem[(i - 1)]
              }else if(any(!is.na(memCorrect[i, 1:9])) &&
                       any(!is.na(memCorrect[(i - 1), 1:9])))
              {
                gtCheck <- which((memCorrect[i, 1:9] >=
                                  memCorrect[(i - 1), 1:9]) == F
                )
                ltCheck <- which((memCorrect[i, 1:9] <=
                                  memCorrect[(i - 1), 1:9]) == F
                )
                eqCheck <- which((memCorrect[i, 1:9] ==
                                  memCorrect[(i - 1), 1:9]) == F
                )
                naCheck <- sum(is.na(memCorrect[i, 1:9])) <
                           sum(is.na(memCorrect[(i - 1), 1:9]))
                if(length(gtCheck) == 0 &&
                   (memCorrect$mem[i] < memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (memCorrect$mem[i] > memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (memCorrect$mem[i] != memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
              }
            }
          }
          patScoCog$mem <- memCorrect$mem
        }
      }
      if(length(dropRows) > 0 && !is.na(dropRows)){
        ad <- data$assessmentDate[-dropRows]
        if(length(ad) > 0){
          ad <- as.Date(sapply(ad, function(x) ifelse(x == 0, NA, x)))
        }else if(length(ad) == 0){
          ad <- NA
        }
      }else{
        ad <- data$assessmentDate
      }
      if(all(!is.na(dropRows))){
        scores <- data.frame(assessmentDate = as.Date(ad), cog = patScoCog$cog,
                             spe = patScoCog$spe, mem = patScoCog$mem,
                             fim = patScoCog$fim, cogSE = patScoCog$cogSE,
                             speSE = patScoCog$speSE, memSE = patScoCog$memSE,
                             fimSE = patScoCog$fimSE
        )
      }else{
        scores <- data.frame(assessmentDate = ad, cog = patScoCog$cog,
                             spe = patScoCog$spe, mem = patScoCog$mem,
                             fim = patScoCog$fim, cogSE = patScoCog$cogSE,
                             speSE = patScoCog$speSE, memSE = patScoCog$memSE,
                             fimSE = patScoCog$fimSE
        )
      }
      if(any(!is.na(ad))){
        naMat <- data.frame(cogInd = rep(1, dim(scoreData)[1]),
                            speInd = apply(scoreData[, speIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            memInd = apply(scoreData[, memIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            fimInd = apply(scoreData[, fimIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            )
        )
      }else{
        naMat <- NA
      }
      scores[, 2:5] <- scores[, 2:5] * naMat
      scores[, 6:9] <- scores[, 6:9] * naMat
    }else if(group == 3){
      scoreData <- data[, c(5:14, 17:19, 22:23, 39:43)]
      fimIts <- 16:20; speIts <- 14:15; memIts <- c(1:6, 11:13); agiIts <- 7:10
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                  function(x) ifelse(x < 7 && !is.na(x),
                                                     x, NA
                                              )
      )
      dropRows <- which(apply(scoreData, 1, function(x) all(is.na(x))))
      if(length(dropRows) > 0){
        scoreData <- scoreData[-dropRows, ]
      }else{
        dropRows <- NA
      }
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      if(dim(scoreData2)[1] > 0){
        patScoCog <- as.data.frame(fscores(cogModBI,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = biMeans,
                                           cov = cogLTCovBI
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'spe',
                                 'mem', 'no1', 'no2', 'no3', 'agi', 'no4',
                                 'cogSE', 'fimSE', 'speSE', 'memSE', 'no1SE',
                                 'no2SE', 'no3SE', 'agiSE', 'no4SE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, 14:15]))){
            scoreData2_spe <- scoreData2
            scoreData2_spe[, c(1:13, 16:20)] <- NA
            naPos <- which(apply(scoreData2_spe[, 14:15], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_spe[naPos, 14] <- 1
            }
            patScoCog_spe <- as.data.frame(fscores(cogModBI,
                                            response.pattern = scoreData2_spe,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = biMeans,
                                            cov = cogLTCovBI
                              )
            )
            colnames(patScoCog_spe) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'spe', 'mem', 'no1', 'no2', 'no3',
                                         'agi', 'no4', 'cogSE', 'fimSE',
                                         'speSE', 'memSE', 'no1SE', 'no2SE',
                                         'no3SE', 'agiSE', 'no4SE'
            )
            patScoCog$spe <- patScoCog_spe$spe
            patScoCog$speSE <- patScoCog_spe$speSE
            if(length(naPos) > 0){
              patScoCog$spe[naPos] <- NA
              patScoCog$speSE[naPos] <- NA
            }
          }else{
            patScoCog$spe <- NA
            patScoCog$speSE <- NA
          }
          if(any(!is.na(scoreData2[, c(1:6, 11:13)]))){
            scoreData2_mem <- scoreData2
            scoreData2_mem[, c(7:10, 14:20)] <- NA
            naPos <- which(apply(scoreData2_mem[, c(1:6, 11:13)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_mem[naPos, 1] <- 1
            }
            patScoCog_mem <- as.data.frame(fscores(cogModBI,
                                            response.pattern = scoreData2_mem,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = biMeans,
                                            cov = cogLTCovBI
                              )
            )
            colnames(patScoCog_mem) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'spe', 'mem', 'no1', 'no2', 'no3',
                                         'agi', 'no4', 'cogSE', 'fimSE',
                                         'speSE', 'memSE', 'no1SE', 'no2SE',
                                         'no3SE', 'agiSE', 'no4SE'
            )
            patScoCog$mem <- patScoCog_mem$mem
            patScoCog$memSE <- patScoCog_mem$memSE
            if(length(naPos) > 0){
              patScoCog$mem[naPos] <- NA
              patScoCog$memSE[naPos] <- NA
            }
          }else{
            patScoCog$mem <- NA
            patScoCog$memSE <- NA
          }
          if(any(!is.na(scoreData2[, 7:10]))){
            scoreData2_agi <- scoreData2
            scoreData2_agi[, c(1:6, 11:20)] <- NA
            naPos <- which(apply(scoreData2_agi[, 7:10], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_agi[naPos, 7] <- 1
            }
            patScoCog_agi <- as.data.frame(fscores(cogModBI,
                                            response.pattern = scoreData2_agi,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = biMeans,
                                            cov = cogLTCovBI
                              )
            )
            colnames(patScoCog_agi) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'spe', 'mem', 'no1', 'no2', 'no3',
                                         'agi', 'no4', 'cogSE', 'fimSE',
                                         'speSE', 'memSE', 'no1SE', 'no2SE',
                                         'no3SE', 'agiSE', 'no4SE'
            )
            patScoCog$agi <- patScoCog_agi$agi
            patScoCog$agiSE <- patScoCog_agi$agiSE
            if(length(naPos) > 0){
              patScoCog$agi[naPos] <- NA
              patScoCog$agiSE[naPos] <- NA
            }
          }else{
            patScoCog$agi <- NA
            patScoCog$agiSE <- NA
          }
        }
      }else{
        patScoCog <- as.data.frame(matrix(
                                     rep(NA,
                                         length(colnames(scoreData2)) + 18
                                     ),
                                     nrow = 1
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'spe',
                                 'mem', 'no1', 'no2', 'no3', 'agi', 'no4',
                                 'cogSE', 'fimSE', 'speSE', 'memSE', 'no1SE',
                                 'no2SE', 'no3SE', 'agiSE', 'no4SE'
        )
      }
      if(marScoSwitch == 0){
        speCorrect <- patScoCog[, c(speIts, 23)]
        if(nrow(speCorrect) > 1){
          for(i in 2:nrow(speCorrect)){
            diffScoCheck <- speCorrect$spe[i] != speCorrect$spe[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(speCorrect[i, 1:2])) &&
                 all(is.na(speCorrect[(i - 1), 1:2])))
              {
                speCorrect$spe[(i)] <- speCorrect$spe[(i - 1)]
              }else if(any(!is.na(speCorrect[i, 1:2])) &&
                       any(!is.na(speCorrect[(i - 1), 1:2])))
              {
                gtCheck <- which((speCorrect[i, 1:2] >=
                                  speCorrect[(i - 1), 1:2]) == F
                )
                ltCheck <- which((speCorrect[i, 1:2] <=
                                  speCorrect[(i - 1), 1:2]) == F
                )
                eqCheck <- which((speCorrect[i, 1:2] ==
                                  speCorrect[(i - 1), 1:2]) == F
                )
                naCheck <- sum(is.na(speCorrect[i, 1:2])) <
                           sum(is.na(speCorrect[(i - 1), 1:2]))
                if(length(gtCheck) == 0 &&
                   (speCorrect$spe[i] < speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (speCorrect$spe[i] > speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (speCorrect$spe[i] != speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
              }
            }
          }
          patScoCog$spe <- speCorrect$spe
        }
        memCorrect <- patScoCog[, c(memIts, 24)]
        if(nrow(memCorrect) > 1){
          for(i in 2:nrow(memCorrect)){
            diffScoCheck <- memCorrect$mem[i] != memCorrect$mem[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(memCorrect[i, 1:9])) &&
                 all(is.na(memCorrect[(i - 1), 1:9])))
              {
                memCorrect$mem[(i)] <- memCorrect$mem[(i - 1)]
              }else if(any(!is.na(memCorrect[i, 1:9])) &&
                       any(!is.na(memCorrect[(i - 1), 1:9])))
              {
                gtCheck <- which((memCorrect[i, 1:9] >=
                                  memCorrect[(i - 1), 1:9]) == F
                )
                ltCheck <- which((memCorrect[i, 1:9] <=
                                  memCorrect[(i - 1), 1:9]) == F
                )
                eqCheck <- which((memCorrect[i, 1:9] ==
                                  memCorrect[(i - 1), 1:9]) == F
                )
                naCheck <- sum(is.na(memCorrect[i, 1:9])) <
                           sum(is.na(memCorrect[(i - 1), 1:9]))
                if(length(gtCheck) == 0 &&
                   (memCorrect$mem[i] < memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (memCorrect$mem[i] > memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (memCorrect$mem[i] != memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
              }
            }
          }
          patScoCog$mem <- memCorrect$mem
        }
        agiCorrect <- patScoCog[, c(agiIts, 28)]
        if(nrow(agiCorrect) > 1){
          for(i in 2:nrow(agiCorrect)){
            diffScoCheck <- agiCorrect$agi[i] != agiCorrect$agi[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(agiCorrect[i, 1:4])) &&
                 all(is.na(agiCorrect[(i - 1), 1:4])))
              {
                agiCorrect$agi[(i)] <- agiCorrect$agi[(i - 1)]
              }else if(any(!is.na(agiCorrect[i, 1:4])) &&
                       any(!is.na(agiCorrect[(i - 1), 1:4])))
              {
                gtCheck <- which((agiCorrect[i, 1:4] >=
                                  agiCorrect[(i - 1), 1:4]) == F
                )
                ltCheck <- which((agiCorrect[i, 1:4] <=
                                  agiCorrect[(i - 1), 1:4]) == F
                )
                eqCheck <- which((agiCorrect[i, 1:4] ==
                                  agiCorrect[(i - 1), 1:4]) == F
                )
                naCheck <- sum(is.na(agiCorrect[i, 1:4])) <
                           sum(is.na(agiCorrect[(i - 1), 1:4]))
                if(length(gtCheck) == 0 &&
                   (agiCorrect$agi[i] < agiCorrect$agi[(i - 1)]) &&
                   !naCheck)
                {
                  agiCorrect$agi[i] <- agiCorrect$agi[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (agiCorrect$agi[i] > agiCorrect$agi[(i - 1)]) &&
                   !naCheck)
                {
                  agiCorrect$agi[i] <- agiCorrect$agi[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (agiCorrect$agi[i] != agiCorrect$agi[(i - 1)]) &&
                   !naCheck)
                {
                  agiCorrect$agi[i] <- agiCorrect$agi[(i - 1)]
                }
              }
            }
          }
          patScoCog$agi <- agiCorrect$agi
        }
      }
      if(length(dropRows) > 0 && !is.na(dropRows)){
        ad <- data$assessmentDate[-dropRows]
        if(length(ad) > 0){
          ad <- as.Date(sapply(ad, function(x) ifelse(x == 0, NA, x)))
        }else if(length(ad) == 0){
          ad <- NA
        }
      }else{
        ad <- data$assessmentDate
      }
      if(all(!is.na(dropRows))){
        scores <- data.frame(assessmentDate = ad, cog = patScoCog$cog,
                             spe = patScoCog$spe, mem = patScoCog$mem,
                             agi = patScoCog$agi, fim = patScoCog$fim,
                             cogSE = patScoCog$cogSE, speSE = patScoCog$speSE,
                             memSE = patScoCog$memSE, agiSE = patScoCog$agiSE,
                             fimSE = patScoCog$fimSE
        )
      }else{
        scores <- data.frame(assessmentDate = ad, cog = patScoCog$cog,
                             spe = patScoCog$spe, mem = patScoCog$mem,
                             agi = patScoCog$agi, fim = patScoCog$fim,
                             cogSE = patScoCog$cogSE, speSE = patScoCog$speSE,
                             memSE = patScoCog$memSE, agiSE = patScoCog$agiSE,
                             fimSE = patScoCog$fimSE
        )
      }
      if(any(!is.na(ad))){
        naMat <- data.frame(cogInd = rep(1, dim(scoreData)[1]),
                            speInd = apply(scoreData[, speIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            memInd = apply(scoreData[, memIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            agiInd = apply(scoreData[, agiIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            fimInd = apply(scoreData[, fimIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            )
        )
      }else{
        naMat <- NA
      }
      scores[, 2:6] <- scores[, 2:6] * naMat
      scores[, 7:11] <- scores[, 7:11] * naMat
    }else if(group == 4){
      scoreData <- data[, c(5:10, 15:17, 22:23, 39:43)]
      fimIts <- 12:16; memIts <- c(1:7, 9)
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                   function(x) ifelse(x < 7 && !is.na(x),
                                                      x, NA
                                               )
      )
      dropRows <- which(apply(scoreData, 1, function(x) all(is.na(x))))
      if(length(dropRows) > 0){
        scoreData <- scoreData[-dropRows, ]
      }else{
        dropRows <- NA
      }
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      if(dim(scoreData2)[1] > 0){
        patScoCog <- as.data.frame(fscores(cogModRHD,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = rhdMeans,
                                           cov = cogLTCovRHD
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'no1',
                                 'mem', 'cogSE', 'fimSE', 'no1SE', 'memSE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, c(1:7, 9)]))){
            scoreData2_mem <- scoreData2
            scoreData2_mem[, c(8, 10:16)] <- NA
            naPos <- which(apply(scoreData2_mem[, c(1:7, 9)], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_mem[naPos, 1] <- 1
            }
            patScoCog_mem <- as.data.frame(fscores(cogModRHD,
                                            response.pattern = scoreData2_mem,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = rhdMeans,
                                            cov = cogLTCovRHD
                              )
            )
            colnames(patScoCog_mem) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'no1', 'mem', 'cogSE', 'fimSE',
                                         'no1SE', 'memSE'
            )
            patScoCog$mem <- patScoCog_mem$mem
            patScoCog$memSE <- patScoCog_mem$memSE
            if(length(naPos) > 0){
              patScoCog$mem[naPos] <- NA
              patScoCog$memSE[naPos] <- NA
            }
          }else{
            patScoCog$mem <- NA
            patScoCog$memSE <- NA
          }
        }
      }else{
        patScoCog <- as.data.frame(matrix(
                                     rep(NA,
                                         length(colnames(scoreData2)) + 8
                                     ),
                                     nrow = 1
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'no1',
                                 'mem', 'cogSE', 'fimSE', 'no1SE', 'memSE'
        )
      }
      if(marScoSwitch == 0){
        memCorrect <- patScoCog[, c(memIts, 20)]
        if(nrow(memCorrect) > 1){
          for(i in 2:nrow(memCorrect)){
            diffScoCheck <- memCorrect$mem[i] != memCorrect$mem[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(memCorrect[i, 1:8])) &&
                 all(is.na(memCorrect[(i - 1), 1:8])))
              {
                memCorrect$mem[(i)] <- memCorrect$mem[(i - 1)]
              }else if(any(!is.na(memCorrect[i, 1:8])) &&
                       any(!is.na(memCorrect[(i - 1), 1:8])))
              {
                gtCheck <- which((memCorrect[i, 1:8] >=
                                  memCorrect[(i - 1), 1:8]) == F
                )
                ltCheck <- which((memCorrect[i, 1:8] <=
                                  memCorrect[(i - 1), 1:8]) == F
                )
                eqCheck <- which((memCorrect[i, 1:8] ==
                                  memCorrect[(i - 1), 1:8]) == F
                )
                naCheck <- sum(is.na(memCorrect[i, 1:8])) <
                           sum(is.na(memCorrect[(i - 1), 1:8]))
                if(length(gtCheck) == 0 &&
                   (memCorrect$mem[i] < memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (memCorrect$mem[i] > memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (memCorrect$mem[i] != memCorrect$mem[(i - 1)]) &&
                   !naCheck)
                {
                  memCorrect$mem[i] <- memCorrect$mem[(i - 1)]
                }
              }
            }
          }
          patScoCog$mem <- memCorrect$mem
        }
      }
      if(length(dropRows) > 0 && !is.na(dropRows)){
        ad <- data$assessmentDate[-dropRows]
        if(length(ad) > 0){
          ad <- as.Date(sapply(ad, function(x) ifelse(x == 0, NA, x)))
        }else if(length(ad) == 0){
          ad <- NA
        }
      }else{
        ad <- data$assessmentDate
      }
      if(all(!is.na(dropRows))){
        scores <- data.frame(assessmentDate = ad, cog = patScoCog$cog,
                             mem = patScoCog$mem, fim = patScoCog$fim,
                             cogSE = patScoCog$cogSE, memSE = patScoCog$memSE,
                             fimSE = patScoCog$fimSE
        )
      }else{
        scores <- data.frame(assessmentDate = ad, cog = patScoCog$cog,
                             mem = patScoCog$mem, fim = patScoCog$fim,
                             cogSE = patScoCog$cogSE, memSE = patScoCog$memSE,
                             fimSE = patScoCog$fimSE
        )
      }
      if(any(!is.na(ad))){
        naMat <- data.frame(cogInd = rep(1, dim(scoreData)[1]),
                            memInd = apply(scoreData[, memIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            ),
                            fimInd = apply(scoreData[, fimIts], 1,
                                           function(x) ifelse(all(is.na(x)),
                                                              NA, 1
                                                       )
                            )
        )
      }else{
        naMat <- NA
      }
      scores[, 2:4] <- scores[, 2:4] * naMat
      scores[, 5:7] <- scores[, 5:7] * naMat
    }else if(group == 5){
      scoreData <- data[, c(20:23, 39:43)]
      fimIts <- 5:9; speIts <- 1:4
      scoreData[, fimIts] <- apply(scoreData[, fimIts], c(1, 2),
                                  function(x) ifelse(x < 7 && !is.na(x),
                                                     x, NA
                                              )
      )
      dropRows <- which(apply(scoreData, 1, function(x) all(is.na(x))))
      if(length(dropRows) > 0){
        scoreData <- scoreData[-dropRows, ]
      }else{
        dropRows <- NA
      }
      if(dim(scoreData)[1] > 1){
        scoreData2 <- apply(scoreData, 2, repeat.before)
      }else{
        scoreData2 <- scoreData
      }
      if(nrow(scoreData2) > 0){
        patScoCog <- as.data.frame(fscores(cogModSpe,
                                           response.pattern = scoreData2,
                                           method = 'MAP',
                                           theta_lim = c(-6, 6),
                                           mean = speMeans,
                                           cov = cogLTCovSpe
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'spe',
                                 'no1', 'cogSE', 'fimSE', 'speSE', 'no1SE'
        )
        if(marScoSwitch == 1){
          if(any(!is.na(scoreData2[, 1:4]))){
            scoreData2_spe <- scoreData2
            scoreData2_spe[, 5:9] <- NA
            naPos <- which(apply(scoreData2_spe[, 1:4], 1,
                                 function(x) all(is.na(x))
            ))
            if(length(naPos) > 0){
              scoreData2_spe[naPos, 1] <- 1
            }
            patScoCog_spe <- as.data.frame(fscores(cogModSpe,
                                            response.pattern = scoreData2_spe,
                                            method = 'MAP',
                                            theta_lim = c(-6, 6),
                                            mean = speMeans,
                                            cov = cogLTCovSpe
                              )
            )
            colnames(patScoCog_spe) <- c(colnames(scoreData2), 'cog', 'fim',
                                         'spe', 'no1', 'cogSE', 'fimSE',
                                         'speSE', 'no1SE'
            )
            patScoCog$spe <- patScoCog_spe$spe
            patScoCog$speSE <- patScoCog_spe$speSE
            if(length(naPos) > 0){
              patScoCog$spe[naPos] <- NA
              patScoCog$speSE[naPos] <- NA
            }
          }else{
            patScoCog$spe <- NA
            patScoCog$speSE <- NA
          }
        }
      }else{
        patScoCog <- as.data.frame(matrix(rep(NA,
                                              length(colnames(scoreData2)) + 8
                                          ),
                                          nrow = 1
                                   )
        )
        colnames(patScoCog) <- c(colnames(scoreData2), 'cog', 'fim', 'spe',
                                 'mem', 'cogSE', 'fimSE', 'speSE', 'memSE'
        )
      }
      if(marScoSwitch == 0){
        speCorrect <- patScoCog[, c(speIts, 12)]
        if(nrow(speCorrect) > 1){
          for(i in 2:nrow(speCorrect)){
            diffScoCheck <- speCorrect$spe[i] != speCorrect$spe[(i - 1)]
            if(diffScoCheck){
              if(all(is.na(speCorrect[i, 1:4])) &&
                 all(is.na(speCorrect[(i - 1), 1:4])))
              {
                speCorrect$spe[(i)] <- speCorrect$spe[(i - 1)]
              }else if(any(!is.na(speCorrect[i, 1:4])) &&
                       any(!is.na(speCorrect[(i - 1), 1:4])))
              {
                gtCheck <- which((speCorrect[i, 1:4] >=
                                  speCorrect[(i - 1), 1:4]) == F
                )
                ltCheck <- which((speCorrect[i, 1:4] <=
                                  speCorrect[(i - 1), 1:4]) == F
                )
                eqCheck <- which((speCorrect[i, 1:4] ==
                                  speCorrect[(i - 1), 1:4]) == F
                )
                naCheck <- sum(is.na(speCorrect[i, 1:4])) <
                           sum(is.na(speCorrect[(i - 1), 1:4]))
                if(length(gtCheck) == 0 &&
                   (speCorrect$spe[i] < speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
                if(length(ltCheck) == 0 &&
                   (speCorrect$spe[i] > speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
                if(length(eqCheck) == 0 &&
                   (speCorrect$spe[i] != speCorrect$spe[(i - 1)]) &&
                   !naCheck)
                {
                  speCorrect$spe[i] <- speCorrect$spe[(i - 1)]
                }
              }
            }
          }
          patScoCog$spe <- speCorrect$spe
        }
      }
      if(all(!is.na(dropRows))){
        scores <- data.frame(assessmentDate = data$assessmentDate[-dropRows],
                             cog = patScoCog$cog, spe = patScoCog$spe,
                             fim = patScoCog$fim, cogSE = patScoCog$cogSE,
                             speSE = patScoCog$speSE, fimSE = patScoCog$fimSE
        )
      }else{
        scores <- data.frame(assessmentDate = data$assessmentDate,
                             cog = patScoCog$cog, spe = patScoCog$spe,
                             fim = patScoCog$fim, cogSE = patScoCog$cogSE,
                             speSE = patScoCog$speSE, fimSE = patScoCog$fimSE
        )
      }
      naMat <- data.frame(cogInd = rep(1, dim(scoreData)[1]),
                          speInd = apply(scoreData[, speIts], 1,
                                         function(x) ifelse(all(is.na(x)),
                                                            NA, 1
                                                     )
                          ),
                          fimInd = apply(scoreData[, fimIts], 1,
                                         function(x) ifelse(all(is.na(x)),
                                                            NA, 1
                                                     )
                          )
      )
      scores[, 2:4] <- scores[, 2:4] * naMat
      scores[, 5:7] <- scores[, 5:7] * naMat
    }else{
      scores <- NULL
    }
    fimData <- scoreData[, which(colnames(scoreData) %in%
                                 c('comprehension', 'expression',
                                   'socialInteraction', 'problemSolving',
                                   'memory'
                                 )
                           )
    ]
    ## This is where things start changing. After changing different
    ## scores to missing using the logic above, some bugs popped up
    ## on the dashboard when switching the patient's cognitive
    ## diagnosis due to rows where all scores were missing. This
    ## solves that problem.
    if(!is.null(scores)){
      if(marScoSwitch == 0){
        if(dim(scores)[1] > 1){
          if(group == 1){
            scoCorrect <- scores[, 2:6]
          }else if(group == 2){
            scoCorrect <- scores[, 2:5]
          }else if(group == 3){
            scoCorrect <- scores[, 2:6]
          }else if(group == 4){
            scoCorrect <- scores[, 2:4]
          }else if(group == 5){
            scoCorrect <- scores[, 2:4]
          }
          scoCorrect <- as.data.frame(apply(scoCorrect, 2, repeat.before))
          if(any(apply(scoCorrect, 2, function(x) all(is.na(x))))){
            scoCorrect <- scoCorrect[, -which(apply(scoCorrect, 2,
                                                    function(x) all(is.na(x))
                                              )
                                        )
            ]
          }
          ## And now we're back on track with the previous domains
          fimRB <- apply(fimData, 2, repeat.before)
          if(!is.null(dim(scoCorrect))){
            for(i in 2:dim(scores)[1]){
              cogs1 <- scoCorrect$cog[i]
              cogs0 <- scoCorrect$cog[(i - 1)]
              others1 <- scoCorrect[i, 2:dim(scoCorrect)[2]]
              others0 <- scoCorrect[(i - 1), 2:dim(scoCorrect)[2]]
              fim1 <- fimRB[i, ]
              fim0 <- fimRB[(i - 1), ]
              if(cogs1 < cogs0){
                check1 <- all((others1 >= others0), na.rm = T)
                check2 <- all(!is.na(others0))
                check3 <- all((fim1 >= fim0), na.rm = T)
                check4 <- all(!is.na(fim0))
                scoCorrect$cog[i] <- ifelse(check1 && check2 && check3 && check4,
                                            scoCorrect$cog[(i - 1)],
                                            scoCorrect$cog[i]
                )
              }else if(cogs1 <= cogs0){
                check1 <- all((others1 <= others0), na.rm = T)
                check2 <- all(!is.na(others0))
                check3 <- all((fim1 <= fim0), na.rm = T)
                check4 <- all(!is.na(fim0))
                scoCorrect$cog[i] <- ifelse(check1 && check2 && check3 && check4,
                                            scoCorrect$cog[(i - 1)],
                                            scoCorrect$cog[i]
                )
              }
            }
            scores$cog <- scoCorrect$cog
          }
        }
      }
      out <- list(scoreData, scores, fimData)
      out
    }else{
      out <- NULL
    }
  }
  
  ## A function for computing the percentages in the sidebar when self-care
  ## data/analysis is displayed. Also contains the code that builds the HTML
  ## for the sidebar that displays this information.
  sidebarSC <- function(){
    ## If the patient has at least some plotted AQ data...
    if(!is.null(isolate(rv$toPlot))){
      ## Create a copy of the rv
      tv$toPlot <- isolate(rv$toPlot)
      ## If the patient has been assessed on more than one day...
      if(isolate(length(tv$toPlot$sc[complete.cases(tv$toPlot$sc)])) > 1){
        ## Impute the AQ scores forward
        isolate(tv$toPlot$sc <- repeat.before(tv$toPlot$sc))
        ## Convert the patient's scores to percentages within the range of
        ## possible AQ-SC scores
        minSC <- isolate(min(min(tv$toPlot$sc, na.rm = T), minScoSC))
        maxSC <- isolate(max(max(tv$toPlot$sc, na.rm = T), maxScoSC))
        scDiff <- round(conv(minSC, maxSC, 0, 100,
                             c(tv$toPlot$sc[1],
                               tv$toPlot$sc[length(tv$toPlot$sc)]
                             )
                        ), 2
        )
        ## Compute the percent change and convert to a character
        scDiff <- scDiff[2] - scDiff[1]
        scDiffNum <- scDiff
        scDiff <- ifelse(!is.na(scDiff) && is.numeric(scDiff),
                         paste(round(scDiff, 2), '%', sep = ''),
                         '0%'
        )
        ## Select an appropriate icon to display next to the computer percent
        ## change
        if(is.na(scDiffNum)){
          scDiffIcon <- 'small minus icon'
        }else if(scDiffNum > 20){
          scDiffIcon <- 'small angle double up icon'
        }else if(scDiffNum > 0){
          scDiffIcon <- 'small angle up icon'
        }else if(scDiffNum == 0){
          scDiffIcon <- 'small minus icon'
        }else if(scDiffNum < -20){
          scDiffIcon <- 'small angle double down icon'
        }else{
          scDiffIcon <- 'small angle down icon'
        }
      ## Otherwise, if the patient has < 2 assessment dates...
      }else{
        ## Display two dashes to indicate no change
        scDiff <- '-'
        scDiffIcon <- 'small minus icon'
      }
      ## Repeat that same process with the balance assessment area within the
      ## self-care domain
      if(isolate(length(rv$toPlot$bal[complete.cases(rv$toPlot$bal)])) > 1){
        if(isolate(uv$balsc_switch) == 1){
          isolate(tv$toPlot$bal <- repeat.before(tv$toPlot$bal))
          minBal <- min(min(tv$toPlot$bal, na.rm = T), minScoBal_sc)
          maxBal <- max(max(tv$toPlot$bal, na.rm = T), maxScoBal_sc)
          balDiff <- round(
                       conv(minBal, maxBal, 0, 100,
                            c(head(tv$toPlot$bal[!is.na(tv$toPlot$bal)], 1),
                              tail(tv$toPlot$bal, 1)
                            )
                       ), 2
          )
          balDiff <- balDiff[2] - balDiff[1]
          balDiffNum <- balDiff
          balDiff <- ifelse(!is.na(balDiff) && is.numeric(balDiff),
                            paste(round(balDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(balDiffNum)){
            balDiffIcon <- 'small minus icon'
          }else if(balDiffNum > 20){
            balDiffIcon <- 'small angle double up icon'
          }else if(balDiffNum > 0){
            balDiffIcon <- 'small angle up icon'
          }else if(balDiffNum == 0){
            balDiffIcon <- 'small minus icon'
          }else if(balDiffNum < -20){
            balDiffIcon <- 'small angle double down icon'
          }else{
            balDiffIcon <- 'small angle down icon'
          }
        }else{
          balDiff <- '-'
          balDiffIcon <- 'small warmgray minus icon'
        }
      }else{
        balDiff <- '-'
        balDiffIcon <- 'small red minus icon'
      }
      ## Now repeat for UEF
      if(isolate(length(rv$toPlot$uef[complete.cases(rv$toPlot$uef)])) > 1){
        if(isolate(uv$uef_switch) == 1){
          isolate(tv$toPlot$uef <- repeat.before(tv$toPlot$uef))
          minUEF <- min(min(tv$toPlot$uef, na.rm = T), minScoUEF)
          maxUEF <- max(max(tv$toPlot$uef, na.rm = T), maxScoUEF)
          uefDiff <- round(
                       conv(minUEF, maxUEF, 0, 100,
                            c(head(tv$toPlot$uef[!is.na(tv$toPlot$uef)], 1),
                              tail(tv$toPlot$uef, 1)
                            )
                       ), 2
          )
          uefDiff <- uefDiff[2] - uefDiff[1]
          uefDiffNum <- uefDiff
          uefDiff <- ifelse(!is.na(uefDiff) && is.numeric(uefDiff),
                            paste(round(uefDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(uefDiffNum)){
            uefDiffIcon <- 'small minus icon'
          }else if(uefDiffNum > 20){
            uefDiffIcon <- 'small angle double up icon'
          }else if(uefDiffNum > 0){
            uefDiffIcon <- 'small angle up icon'
          }else if(uefDiffNum == 0){
            uefDiffIcon <- 'small minus icon'
          }else if(uefDiffNum < -20){
            uefDiffIcon <- 'small angle double down icon'
          }else{
            uefDiffIcon <- 'small angle down icon'
          }
        }else{
          uefDiff <- '-'
          uefDiffIcon <- 'small yellow minus icon'
        }
      }else{
        uefDiff <- '-'
        uefDiffIcon <- 'small yellow minus icon'
      }
      ## And repeat once more for swallowing
      if(isolate(length(rv$toPlot$swl[complete.cases(rv$toPlot$swl)])) > 1){
        if(isolate(uv$swl_switch) == 1){
          isolate(tv$toPlot$swl <- repeat.before(tv$toPlot$swl))
          minSwl <- min(min(tv$toPlot$swl, na.rm = T), minScoSwl)
          maxSwl <- max(max(tv$toPlot$swl, na.rm = T), maxScoSwl)
          swlDiff <- round(
                       conv(minSwl, maxSwl, 0, 100,
                            c(head(tv$toPlot$swl[!is.na(tv$toPlot$swl)], 1),
                              tail(tv$toPlot$swl, 1)
                            )
                       ), 2
          )
          swlDiff <- swlDiff[2] - swlDiff[1]
          swlDiffNum <- swlDiff
          swlDiff <- ifelse(!is.na(swlDiff) && is.numeric(swlDiff),
                            paste(round(swlDiff, 2), '%', sep = ''), '%0'
          )
          if(is.na(swlDiffNum)){
            swlDiffIcon <- 'small minus icon'
          }else if(swlDiffNum > 20){
            swlDiffIcon <- 'small angle double up icon'
          }else if(swlDiffNum > 0){
            swlDiffIcon <- 'small angle up icon'
          }else if(swlDiffNum == 0){
            swlDiffIcon <- 'small minus icon'
          }else if(swlDiffNum < -20){
            swlDiffIcon <- 'small angle double down icon'
          }else{
            swlDiffIcon <- 'small angle down icon'
          }
        }else{
          swlDiff <- '-'
          swlDiffIcon <- 'small purple minus icon'
        }
      }else{
        swlDiff <- '-'
        swlDiffIcon <- 'small purple minus icon'
      }
    ## Otherwise, if the patient has no plotted data at all, just display all
    ## dashes to indicate no data/no change
    }else{
      scDiff <- '-'; scDiffIcon <- 'small orange minus icon'
      balDiff <- '-'; balDiffIcon <- 'small red minus icon'
      uefDiff <- '-'; uefDiffIcon <- 'small yellow minus icon'
      swlDiff <- '-'; swlDiffIcon <- 'small purple minus icon'
    }
    ## Now that the percent changes and appropriate icons have been selected,
    ## set up the HTML to appear within the sidebar
    output$patStats <- renderUI({
      div(class = 'ui inverted center aligned segment',
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  ## I used a span here because <p> wouldn't center align
                  ## properly. The span seems to float center okay
                  HTML(paste('<span class = orange>', scDiff, '</span>')),
                  ## I know the !important is poor form, but semantic UI really
                  ## wants their icons to diplay white or black.
                  uiicon(scDiffIcon, style = 'color: #f36b21 !important;')
              ),
              div(class = 'center aligned label',
                  ## The &#916 displays a Greek capital delta
                  HTML('<span style = "font-size: 19px;">
                          &#916 Self Care
                        </span>'
                  )
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 1em;'
          ),
          ## Except for swallowing, the buttons here no longer have an event
          ## handler for removing the assessment area from the TRC chart
          div(class = 'ui button',
              style = 'height: 100%; width: 100%; background-color: #1B1C1D;',
              id = 'balsc_ad',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste(ifelse(uv$balsc_switch == 1,
                                        '<span class = red>',
                                        '<span class = warmgray>'
                                 ),
                                 balDiff, '</span>'
                      )),
                      uiicon(balDiffIcon,
                             style = ifelse(uv$balsc_switch == 1,
                                            'color: #ed1c2c !important;',
                                            'color: #6e6259 !important;'
                                     )
                      )
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px;">
                              &#916 Balance
                            </span>'
                      )
                  )
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 1em;'
          ),
          div(class = 'ui button',
              style = 'height: 100%; width: 100%; background-color: #1B1C1D;',
              id = 'uef_ad',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste(ifelse(uv$uef_switch == 1,
                                        '<span class = yellow>',
                                        '<span class = warmgray>'
                                 ), uefDiff, '</span>'
                      )),
                      uiicon(uefDiffIcon,
                             style = ifelse(uv$uef_switch == 1,
                                            'color: #ffd100 !important;',
                                            'color: #6e6259 !important;'
                                     )
                      )
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px;">
                              &#916 UE Function
                            </span>'
                      )
                  )
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 1em;'
          ),
          div(class = 'ui button',
              style = 'height: 100%; width: 100%; background-color: #1B1C1D;',
              id = 'swl_ad',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste(ifelse(uv$swl_switch == 1,
                                        '<span class = purple>',
                                        '<span class = warmgray>'
                                 ), swlDiff, '</span>'
                      )),
                      uiicon(swlDiffIcon,
                             style = ifelse(uv$swl_switch == 1,
                                            'color: #6d2077 !important;',
                                            'color: #6e6259 !important;'
                                     )
                      )
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px;">
                              &#916 Swallowing
                            </span>'
                      )
                  )
              )
          )
      )
    })
    ## Now that the percentages have all been computed and displayed, below
    ## that, display some basic patient information as well.
    output$patStats2 <- renderUI({
      div(class = 'ui inverted center aligned segment',
          ## First, the patient's name
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                HTML(paste('<span class = orange style = "font-size: 1.5vw;">',
                              isolate(rv$row$Name), 
                           '</span>'
                ))
            ),
            div(class = 'center aligned label',
                HTML(paste('<span class = white style = "font-size: 19px;">
                              Name
                            </span>'
                ))
            )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          ## Now the number of days the patient has been at the hospital
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class = tooltipSB
                                    aria-label = "',
                                    as.numeric(Sys.Date() - rv$admit),
                                    ' Days Ago"',
                             '>
                                <span class = orange
                                      style = "font-size: 1.5vw;"
                                >',
                                  ifelse(is.na(rv$admit), 'Not recorded',
                                         as.character(rv$admit)
                                  ),
                               '</span>
                             </span>', sep = ''
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                                Admit Date
                              </span>'
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          ## Now, the expected discharge date
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class =',
                                    ifelse(is.na(rv$depart),
                                           'tooltipSB2', 'tooltipSB'
                                    ),
                                    ' aria-label = "',
                                    ifelse(is.na(rv$depart),
                                           '?',
                                           as.numeric(rv$depart - Sys.Date())
                                    ),
                                    ' Days Left"',
                             '>
                                <span class = orange
                                      style = "font-size: 1.5vw;"
                                >',
                                  ifelse(is.na(rv$depart), 'Not recorded',
                                         as.character(rv$depart)
                                  ),
                               '</span>
                              </span>', sep = ''
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                               Depart Date
                              </span>'
                    
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          ## And also their medical service/diagnosis
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
            div(class = 'center aligned value',
                HTML(paste('<span class = orange style = "font-size: 1.5vw;">',
                              isolate(rv$row$MedicalService),
                           '</span>'
                ))
            ),
            div(class = 'center aligned label',
                HTML(paste('<span class = white style = "font-size: 19px;">
                              Medical Service
                            </span>'
                ))
            )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          )
      )
    })
  }
  
  ## Sets up the sidebar when the mobility domain has been selected. It is
  ## virtually the same in form as the Self-Care one, but configured to display
  ## changes in mobility and its assessment areas. See sidebarSC for markup
  ## info. The only difference in functionality here is that a selector is used
  ## to see if the patient is measured in the Wheelchair group; if so, the
  ## "changing body position" assessment area is displayed.
  sidebarMob <- function(){
    if(!is.null(rv$toPlot) && any(!is.na(rv$toPlot$mob))){
      if(is.null(gv$toPlot)){
        tv$toPlot <- rv$toPlot
      }else{
        tv$toPlot <- gv$toPlot
      }
      if(length(tv$toPlot$mob[complete.cases(tv$toPlot$mob)]) > 1){
        tv$toPlot$mob <- repeat.before(tv$toPlot$mob)
        minMob <- min(min(tv$toPlot$mob, na.rm = T), minScoMob)
        maxMob <- max(max(tv$toPlot$mob, na.rm = T), maxScoMob)
        mobDiff <- round(
                     conv(minMob, maxMob, 0, 100,
                          c(tv$toPlot$mob[1],
                            tv$toPlot$mob[length(tv$toPlot$mob)]
                          )
                     ), 2
        )
        mobDiff <- mobDiff[2] - mobDiff[1]
        mobDiffNum <- mobDiff
        mobDiff <- ifelse(!is.na(mobDiff) && is.numeric(mobDiff),
                          paste(round(mobDiff, 2), '%', sep = ''), '0%'
        )
        if(is.na(mobDiffNum)){
          mobDiffIcon <- 'small minus icon'
        }else if(mobDiffNum > 20){
          mobDiffIcon <- 'small angle double up icon'
        }else if(mobDiffNum > 0){
          mobDiffIcon <- 'small angle up icon'
        }else if(mobDiffNum == 0){
          mobDiffIcon <- 'small minus icon'
        }else if(mobDiffNum < -20){
          mobDiffIcon <- 'small angle double down icon'
        }else{
          mobDiffIcon <- 'small angle down icon'
        }
      }else{
        mobDiff <- '-'
        mobDiffIcon <- 'small minus icon'
      }
      if(length(tv$toPlot$bal[complete.cases(tv$toPlot$bal)]) > 1){
        if(uv$balmob_switch == 1){
          tv$toPlot$bal <- repeat.before(tv$toPlot$bal)
          minBal <- min(min(tv$toPlot$bal, na.rm = T), minScoBal_mob)
          maxBal <- max(max(tv$toPlot$bal, na.rm = T), maxScoBal_mob)
          balDiff <- round(
                       conv(minBal, maxBal, 0, 100,
                            c(head(tv$toPlot$bal[!is.na(tv$toPlot$bal)], 1),
                              tail(tv$toPlot$bal, 1)
                            )
                       ), 2
          )
          balDiff <- balDiff[2] - balDiff[1]
          balDiffNum <- balDiff
          balDiff <- ifelse(!is.na(balDiff) && is.numeric(balDiff),
                            paste(round(balDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(balDiffNum)){
            balDiffIcon <- 'small minus icon'
          }else if(balDiffNum > 20){
            balDiffIcon <- 'small angle double up icon'
          }else if(balDiffNum > 0){
            balDiffIcon <- 'small angle up icon'
          }else if(balDiffNum == 0){
            balDiffIcon <- 'small minus icon'
          }else if(balDiffNum < -20){
            balDiffIcon <- 'small angle double down icon'
          }else{
            balDiffIcon <- 'small angle down icon'
          }
        }else{
          balDiff <- '-'
          balDiffIcon <- 'small minus icon'
        }
      }else{
        balDiff <- '-'
        balDiffIcon <- 'small minus icon'
      }
      ## As with the swallowing section in the self-care sidebar function, the
      ## button for wheelchair skills here does work.
      if(length(tv$toPlot$wc[complete.cases(tv$toPlot$wc)]) > 1){
        if(uv$wc_switch == 1){
          tv$toPlot$wc <- repeat.before(tv$toPlot$wc)
          minWC <- min(min(tv$toPlot$wc, na.rm = T), minScoWC)
          maxWC <- max(max(tv$toPlot$wc, na.rm = T), maxScoWC)
          wcDiff <- round(
                      conv(minWC, maxWC, 0, 100,
                           c(head(tv$toPlot$wc[!is.na(tv$toPlot$wc)], 1),
                             tail(tv$toPlot$wc, 1)
                           )
                      ), 2
          )
          wcDiff <- wcDiff[2] - wcDiff[1]
          wcDiffNum <- wcDiff
          wcDiff <- ifelse(!is.na(wcDiff) && is.numeric(wcDiff),
                           paste(round(wcDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(wcDiffNum)){
            wcDiffIcon <- 'small minus icon'
          }else if(wcDiffNum > 20){
            wcDiffIcon <- 'small angle double up icon'
          }else if(wcDiffNum > 0){
            wcDiffIcon <- 'small angle up icon'
          }else if(wcDiffNum == 0){
            wcDiffIcon <- 'small minus icon'
          }else if(wcDiffNum < -20){
            wcDiffIcon <- 'small angle double down icon'
          }else{
            wcDiffIcon <- 'small angle down icon'
          }
        }else{
          wcDiff <- '-'
          wcDiffIcon <- 'small minus icon'
        }
      }else{
        wcDiff <- '-'
        wcDiffIcon <- 'small minus icon'
      }
      if(length(tv$toPlot$xfer[complete.cases(tv$toPlot$xfer)]) > 1){
        if(uv$xfer_switch == 1){
          tv$toPlot$xfer <- repeat.before(tv$toPlot$xfer)
          minXfer <- min(min(tv$toPlot$xfer, na.rm = T), minScoXfer)
          maxXfer <- max(max(tv$toPlot$xfer, na.rm = T), maxScoXfer)
          xferDiff <- round(
                        conv(minXfer, maxXfer, 0, 100,
                             c(head(tv$toPlot$xfer[!is.na(tv$toPlot$xfer)], 1),
                               tail(tv$toPlot$xfer, 1)
                             )
                        ), 2
          )
          xferDiff <- xferDiff[2] - xferDiff[1]
          xferDiffNum <- xferDiff
          xferDiff <- ifelse(!is.na(xferDiff) && is.numeric(xferDiff),
                             paste(round(xferDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(xferDiffNum)){
            xferDiffIcon <- 'small minus icon'
          }else if(xferDiffNum > 20){
            xferDiffIcon <- 'small angle double up icon'
          }else if(xferDiffNum > 0){
            xferDiffIcon <- 'small angle up icon'
          }else if(xferDiffNum == 0){
            xferDiffIcon <- 'small minus icon'
          }else if(xferDiffNum < -20){
            xferDiffIcon <- 'small angle double down icon'
          }else{
            xferDiffIcon <- 'small angle down icon'
          }
        }else{
          xferDiff <- '-'
          xferDiffIcon <- 'small minus icon'
        }
      }else{
        xferDiff <- '-'
        xferDiffIcon <- 'small minus icon'
      }
      if(length(tv$toPlot$cbp[complete.cases(tv$toPlot$cbp)]) > 1){
        if(uv$cbp_switch == 1){
          tv$toPlot$cbp <- repeat.before(tv$toPlot$cbp)
          minCBP <- min(min(tv$toPlot$cbp, na.rm = T), minScoCBP)
          maxCBP <- max(max(tv$toPlot$cbp, na.rm = T), maxScoCBP)
          cbpDiff <- round(conv(minCBP, maxCBP, 0, 100,
                                c(head(
                                    tv$toPlot$cbp[!is.na(tv$toPlot$cbp)], 1
                                  ),
                                  tail(tv$toPlot$cbp, 1)
                                )
                           ), 2
          )
          cbpDiff <- cbpDiff[2] - cbpDiff[1]
          cbpDiffNum <- cbpDiff
          cbpDiff <- ifelse(!is.na(cbpDiff) && is.numeric(cbpDiff),
                            paste(round(cbpDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(cbpDiffNum)){
            cbpDiffIcon <- 'small minus icon'
          }else if(cbpDiffNum > 20){
            cbpDiffIcon <- 'small angle double up icon'
          }else if(cbpDiffNum > 0){
            cbpDiffIcon <- 'small angle up icon'
          }else if(cbpDiffNum == 0){
            cbpDiffIcon <- 'small minus icon'
          }else if(cbpDiffNum < -20){
            cbpDiffIcon <- 'small angle double down icon'
          }else{
            cbpDiffIcon <- 'small angle down icon'
          }
        }else{
          cbpDiff <- '-'
          cbpDiffIcon <- 'small minus icon'
        }
      }else{
        cbpDiff <- '-'
        cbpDiffIcon <- 'small minus icon'
      }
    }else{
      mobDiff <- '-'; mobDiffIcon <- 'small orange minus icon'
      balDiff <- '-'; balDiffIcon <- 'small red minus icon'
      wcDiff <- '-'; wcDiffIcon <- 'small yellow minus icon'
      xferDiff <- '-'; xferDiffIcon <- 'small purple minus icon'
      cbpDiff <- '-'; cbpDiffIcon <- 'small purple minus icon'
    }
    ## This part evaluates the patient's mobility group
    if(is.null(gv$mobgroup)){
      group <- isolate(rv$mobgroup)
    }else{
      group <- isolate(gv$mobgroup)
    }
    ## If the patient is in the Wheelchair group...
    if(group == 1){
      output$patStats <- renderUI({
        div(class = 'ui inverted center aligned segment',
            div(class = 'ui small inverted center aligned statistic',
                style = 'margin: 0 auto;',
                div(class = 'center aligned value',
                    HTML(paste('<span class = orange>', mobDiff, '</span>')),
                    uiicon(mobDiffIcon, style = 'color: #f36b21 !important;')
                ),
                div(class = 'center aligned label',
                    HTML('<span style = "font-size: 19px;">
                            &#916 Mobility
                          </span>'
                    )
                )
            ),
            div(class = 'ui divider',
                style = 'margin-top: 1em; margin-bottom: 1em;'
            ),
            div(class = 'ui button',
                style = 'height: 100%; width: 100%;
                         background-color: #1B1C1D;',
                id = 'balmob_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$balmob_switch == 1,
                                          '<span class = red>',
                                          '<span class = warmgray>'
                                   ), balDiff, '</span>'
                        )),
                        uiicon(balDiffIcon,
                               style = ifelse(uv$balmob_switch == 1,
                                              'color: #ed1c2c !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Balance
                              </span>'
                        )
                    )
                )
            ),
            div(class = 'ui divider',
                style = 'margin-top: 1em; margin-bottom: 1em;'
            ),
            div(class = 'ui button',
                style = 'height: 100%; width: 100%;
                         background-color: #1B1C1D;',
                id = 'wc_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$wc_switch == 1,
                                          '<span class = yellow>',
                                          '<span class = warmgray>'
                                   ), wcDiff, '</span>'
                        )),
                        uiicon(wcDiffIcon,
                               style = ifelse(uv$wc_switch == 1,
                                              'color: #ffd100 !important',
                                              'color: #6e6259 !important'
                                       )
                        )
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Wheelchair Skills
                              </span>'
                        )
                    )
                )
            ),
            div(class = 'ui divider',
                style = 'margin-top: 1em; margin-bottom: 1em;'
            ),
            div(class = 'ui button',
                style = 'height: 100%; width: 100%;
                         background-color: #1B1C1D;',
                id = 'xfer_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$xfer_switch == 1,
                                          '<span class = purple>',
                                          '<span class = warmgray>'
                                   ), xferDiff, '</span>'
                        )),
                        uiicon(xferDiffIcon,
                               style = ifelse(uv$xfer_switch == 1,
                                              'color: #6d2077 !important;',
                                              'color: #6e6259 !important;'
                               ))
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Bathroom Transfers
                              </span>'
                        )
                    )
                )
            ),
            div(class = 'ui divider',
                style = 'margin-top: 1em; margin-bottom: 1em;'
            ),
            div(class = 'ui button',
                style = 'height: 100%; width: 100%;
                         background-color: #1B1C1D;',
                id = 'cbp_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$cbp_switch == 1,
                                          '<span class = maroon>',
                                          '<span class = warmgray>'
                                   ), cbpDiff, '</span>'
                        )),
                        uiicon(cbpDiffIcon,
                               style = ifelse(uv$cbp_switch == 1,
                                              'color: #861f41 !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Changing Body Position
                              </span>'
                        )
                    )
                )
            )
        )
      })
    ## Otherwise, if the patient is in the "Both" or "Walking"
    }else if(group %in% c(2, 3)){
      output$patStats <- renderUI({
        div(class = 'ui inverted center aligned segment',
            div(class = 'ui small inverted center aligned statistic',
                style = 'margin: 0 auto;',
                div(class = 'center aligned value',
                    HTML(paste('<span class = orange>',
                                  mobDiff,
                               '</span>'
                    )),
                    uiicon(mobDiffIcon, style = 'color: #f36b21 !important;')
                ),
                div(class = 'center aligned label',
                    HTML('<span style = "font-size: 19px">
                            &#916 Mobility
                          </span>'
                    )
                )
            ),
            div(class = 'ui divider',
                style = 'margin-top: 1em; margin-bottom: 1em;'
            ),
            div(class = 'ui button',
                style = 'height: 100%; width: 100%;
                         background-color: #1B1C1D;',
                id = 'balmob_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$balmob_switch == 1,
                                          '<span class = red>',
                                          '<span class = warmgray>'
                                   ), balDiff, '</span>'
                        )),
                        uiicon(balDiffIcon,
                               style = ifelse(uv$balmob_switch == 1,
                                              'color: #ed1c2c !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Balance/Walking
                              </span>'
                        )
                    )
                )
            ),
            div(class = 'ui divider',
                style = 'margin-top: 1em; margin-bottom: 1em;'
            ),
            div(class = 'ui button',
                style = 'height: 100%; width: 100%;
                         background-color: #1B1C1D;',
                id = 'wc_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$wc_switch == 1,
                                          '<span class = yellow>',
                                          '<span class = warmgray>'
                                   ), wcDiff, '</span>'
                        )),
                        uiicon(wcDiffIcon,
                               style = ifelse(uv$wc_switch == 1,
                                              'color: #ffd100 !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Wheelchair Skills
                             </span>'
                        )
                    )
                )
            ),
            div(class = 'ui divider',
                style = 'margin-top: 1em; margin-bottom: 1em;'
            ),
            div(class = 'ui button',
                style = 'height: 100%; width: 100%;
                         background-color: #1B1C1D;',
                id = 'xfer_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$xfer_switch == 1,
                                          '<span class = purple>',
                                          '<span class = warmgray>'
                                   ), xferDiff, '</span>'
                        )),
                        uiicon(xferDiffIcon,
                               style = ifelse(uv$xfer_switch == 1,
                                              'color: #6d2077 !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Bathroom Transfers
                              </span>'
                        )
                    )
                )
            )
        )
      })
    }
    
    output$patStats2 <- renderUI({
      div(class = 'ui inverted center aligned segment',
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class = orange
                                    style = "font-size: 1.5vw;">',
                                isolate(rv$row$Name),
                             '</span>'
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                                Name
                              </span>'
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class = tooltipSB
                                    aria-label = "',
                                    as.numeric(Sys.Date() - rv$admit),
                                    ' Days Ago"',
                             '>
                                <span class = orange
                                      style = "font-size: 1.5vw;"
                                >',
                                  ifelse(is.na(rv$admit), 'Not recorded',
                                         as.character(rv$admit)
                                  ),
                               '</span>
                             </span>', sep = ''
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                                Admit Date
                              </span>'
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class =',
                                    ifelse(is.na(rv$depart),
                                           'tooltipSB2', 'tooltipSB'
                                    ),
                                    ' aria-label = "',
                                    ifelse(is.na(rv$depart),
                                           '?',
                                           as.numeric(rv$depart - Sys.Date())
                                    ),
                                    ' Days Left"',
                             '>
                                <span class = orange
                                      style = "font-size: 1.5vw;"
                                >',
                                  ifelse(is.na(rv$depart), 'Not recorded',
                                         as.character(rv$depart)
                                  ),
                               '</span>
                              </span>', sep = ''
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                               Depart Date
                              </span>'
                    
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class = orange
                                    style = "font-size: 1.5vw;">',
                                isolate(rv$row$MedicalService),
                             '</span>'
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px">
                                Medical Service
                              </span>'
                  ))
              )
            ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em'
          )
      )
    })
  }
  
  ## Sets up the sidebar when the cognition domain is selected. Once again,
  ## this function is very close to its self-care and mobility counterparts,
  ## but has more selectors as the AQ-Cog is a 5-group model with specific
  ## measures assessed on each group (with some amount of overlap). The only
  ## mark-up here points out sections specific to each of those groups and a
  ## few other points of interest.
  sidebarCog <- function(){
    if(!is.null(rv$toPlot)){
      tv$toPlot <- isolate(rv$toPlot)
      ## Identify the patient's cognition group, then specify which assessment
      ## areas aren't relevant
      if(is.null(gv$coggroup)){
        group <- isolate(rv$coggroup)
      }else{
        group <- isolate(gv$coggroup)
      }
      if(!is.na(group)){
        if(isolate(group) == 1){
          tv$toPlot$spe <- NA
          tv$toPlot$mem <- NA
          tv$toPlot$agi <- NA
        }else if(isolate(group) == 2){
          tv$toPlot$com <- NA
          tv$toPlot$wcom <- NA
          tv$toPlot$comp <- NA
          tv$toPlot$agi <- NA
        }else if(isolate(group) == 3){
          tv$toPlot$com <- NA
          tv$toPlot$wcom <- NA
          tv$toPlot$comp <- NA
        }else if(isolate(group) == 4){
          tv$toPlot$spe <- NA
          tv$toPlot$com <- NA
          tv$toPlot$wcom <- NA
          tv$toPlot$comp <- NA
          tv$toPlot$agi <- NA
        }else if(isolate(group) == 5){
          tv$toPlot$mem <- NA
          tv$toPlot$com <- NA
          tv$toPlot$wcom <- NA
          tv$toPlot$comp <- NA
          tv$toPlot$agi <- NA
        }
      }
      if(length(rv$toPlot$cog[complete.cases(tv$toPlot$cog)]) > 1){
        tv$toPlot$cog <- repeat.before(tv$toPlot$cog)
        minCog <- min(min(tv$toPlot$cog, na.rm = T), minScoCog)
        maxCog <- max(max(tv$toPlot$cog, na.rm = T), maxScoCog)
        cogDiff <- round(
                     conv(minCog, maxCog, 0, 100,
                          c(tv$toPlot$cog[1],
                            tv$toPlot$cog[length(tv$toPlot$cog)]
                          )
                     ), 2
        )
        cogDiff <- cogDiff[2] - cogDiff[1]
        cogDiffNum <- cogDiff
        cogDiff <- ifelse(!is.na(cogDiff) && is.numeric(cogDiff),
                          paste(round(cogDiff, 2), '%', sep = ''), '0%'
        )
        if(is.na(cogDiffNum)){
          cogDiffIcon <- 'small minus icon'
        }else if(cogDiffNum > 20){
          cogDiffIcon <- 'small angle double up icon'
        }else if(cogDiffNum > 0){
          cogDiffIcon <- 'small angle up icon'
        }else if(cogDiffNum == 0){
          cogDiffIcon <- 'small minus icon'
        }else if(cogDiffNum < -20){
          cogDiffIcon <- 'small angle double down icon'
        }else{
          cogDiffIcon <- 'small angle down icon'
        }
      }else{
        cogDiff <- '-'
        cogDiffIcon <- 'small minus icon'
      }
      if(!('spe' %in% colnames(tv$toPlot))){
        tv$toPlot$spe <- NA
      }
      ## Compute the change in speech if there's at least 2 speech measurements
      if(length(tv$toPlot$spe[complete.cases(tv$toPlot$spe)]) > 1){
        if(uv$spe_switch == 1){
          tv$toPlot$spe <- repeat.before(tv$toPlot$spe)
          minSpe <- min(min(tv$toPlot$spe, na.rm = T), minScoSpe)
          maxSpe <- max(max(tv$toPlot$spe, na.rm = T), maxScoSpe)
          speDiff <- round(
                       conv(minSpe, maxSpe, 0, 100,
                            c(head(tv$toPlot$spe[!is.na(tv$toPlot$spe)], 1),
                              tail(tv$toPlot$spe, 1)
                            )
                       ), 2
          )
          speDiff <- speDiff[2] - speDiff[1]
          speDiffNum <- speDiff
          speDiff <- ifelse(!is.na(speDiff) && is.numeric(speDiff),
                            paste(round(speDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(speDiffNum)){
            speDiffIcon <- 'small minus icon'
          }else if(speDiffNum > 20){
            speDiffIcon <- 'small angle double up icon'
          }else if(speDiffNum > 0){
            speDiffIcon <- 'small angle up icon'
          }else if(speDiffNum == 0){
            speDiffIcon <- 'small minus icon'
          }else if(speDiffNum < -20){
            speDiffIcon <- 'small angle double down icon'
          }else{
            speDiffIcon <- 'small angle down icon'
          }
        }else{
          speDiff <- '-'
          speDiffIcon <- 'small minus icon'
        }
      }else{
        speDiff <- '-'
        speDiffIcon <- 'small minus icon'
      }
      if(!('mem' %in% colnames(tv$toPlot))){
        tv$toPlot$mem <- NA
      }
      ## If the patient has at least two memory assessmetns, compute the change
      if(length(tv$toPlot$mem[complete.cases(tv$toPlot$mem)]) > 1){
        if(uv$mem_switch == 1){
          tv$toPlot$mem <- repeat.before(tv$toPlot$mem)
          minMem <- min(min(tv$toPlot$mem, na.rm = T), minScoMem)
          maxMem <- max(max(tv$toPlot$mem, na.rm = T), maxScoMem)
          memDiff <- round(
                       conv(minMem, maxMem, 0, 100,
                            c(head(tv$toPlot$mem[!is.na(tv$toPlot$mem)], 1),
                              tail(tv$toPlot$mem, 1)
                            )
                       ), 2
          )
          memDiff <- memDiff[2] - memDiff[1]
          memDiffNum <- memDiff
          memDiff <- ifelse(!is.na(memDiff) && is.numeric(memDiff),
                            paste(round(memDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(memDiffNum)){
            memDiffIcon <- 'small minus icon'
          }else if(memDiffNum > 20){
            memDiffIcon <- 'small angle double up icon'
          }else if(memDiffNum > 0){
            memDiffIcon <- 'small angle up icon'
          }else if(memDiffNum == 0){
            memDiffIcon <- 'small minus icon'
          }else if(memDiffNum < -20){
            memDiffIcon <- 'small angle double down icon'
          }else{
            memDiffIcon <- 'small angle down icon'
          }
        }else{
          memDiff <- '-'
          memDiffIcon <- 'small minus icon'
        }
      }else{
        memDiff <- '-'
        memDiffIcon <- 'small minus icon'
      }
      if(!('com' %in% colnames(tv$toPlot))){
        tv$toPlot$com <- NA
      }
      ## Compute communication change if there's at least two assessments
      if(length(tv$toPlot$com[complete.cases(tv$toPlot$com)]) > 1){
        if(uv$com_switch == 1){
          tv$toPlot$com <- repeat.before(tv$toPlot$com)
          minCom <- min(min(tv$toPlot$com, na.rm = T), minScoCom)
          maxCom <- max(max(tv$toPlot$com, na.rm = T), maxScoCom)
          comDiff <- round(
                       conv(minCom, maxCom, 0, 100,
                            c(head(tv$toPlot$com[!is.na(tv$toPlot$com)], 1),
                              tail(tv$toPlot$com, 1)
                            )
                       ), 2
          )
          comDiff <- comDiff[2] - comDiff[1]
          comDiffNum <- comDiff
          comDiff <- ifelse(!is.na(comDiff) && is.numeric(comDiff),
                            paste(round(comDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(comDiffNum)){
            comDiffIcon <- 'small minus icon'
          }else if(comDiffNum > 20){
            comDiffIcon <- 'small angle double up icon'
          }else if(comDiffNum > 0){
            comDiffIcon <- 'small angle up icon'
          }else if(comDiffNum == 0){
            comDiffIcon <- 'small minus icon'
          }else if(comDiffNum < -20){
            comDiffIcon <- 'small angle double down icon'
          }else{
            comDiffIcon <- 'small angle down icon'
          }
        }else{
          comDiff <- '-'
          comDiffIcon <- 'small minus icon'
        }
      }else{
        comDiff <- '-'
        comDiffIcon <- 'small minus icon'
      }
      if(!('wcom' %in% colnames(tv$toPlot))){
        tv$toPlot$wcom <- NA
      }
      if(length(tv$toPlot$wcom[complete.cases(tv$toPlot$wcom)]) > 1){
        if(uv$wcom_switch == 1){
          tv$toPlot$wcom <- repeat.before(tv$toPlot$wcom)
          minWCom <- min(min(tv$toPlot$wcom, na.rm = T), minScoWCom)
          maxWCom <- max(max(tv$toPlot$wcom, na.rm = T), maxScoWCom)
          wcomDiff <- round(
                        conv(minWCom, maxWCom, 0, 100,
                             c(head(tv$toPlot$wcom[!is.na(tv$toPlot$wcom)], 1),
                               tail(tv$toPlot$wcom, 1)
                             )
                        ), 2
          )
          wcomDiff <- wcomDiff[2] - wcomDiff[1]
          wcomDiffNum <- wcomDiff
          wcomDiff <- ifelse(!is.na(wcomDiff) && is.numeric(wcomDiff),
                             paste(round(wcomDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(wcomDiffNum)){
            wcomDiffIcon <- 'small minus icon'
          }else if(wcomDiffNum > 20){
            wcomDiffIcon <- 'small angle double up icon'
          }else if(wcomDiffNum > 0){
            wcomDiffIcon <- 'small angle up icon'
          }else if(wcomDiffNum == 0){
            wcomDiffIcon <- 'small minus icon'
          }else if(wcomDiffNum < -20){
            wcomDiffIcon <- 'small angle double down icon'
          }else{
            wcomDiffIcon <- 'small angle down icon'
          }
        }else{
          wcomDiff <- '-'
          wcomDiffIcon <- 'small minus icon'
        }
      }else{
        wcomDiff <- '-'
        wcomDiffIcon <- 'small minus icon'
      }
      if(!('comp' %in% colnames(tv$toPlot))){
        tv$toPlot$comp <- NA
      }
      if(length(tv$toPlot$comp[complete.cases(tv$toPlot$comp)]) > 1){
        if(uv$comp_switch == 1){
          tv$toPlot$comp <- repeat.before(tv$toPlot$comp)
          minComp <- min(min(tv$toPlot$comp, na.rm = T), minScoComp)
          maxComp <- max(max(tv$toPlot$comp, na.rm = T), maxScoComp)
          compDiff <- round(
                        conv(minComp, maxComp, 0, 100,
                             c(head(tv$toPlot$comp[!is.na(tv$toPlot$comp)], 1),
                               tail(tv$toPlot$comp, 1)
                             )
                        ), 2
          )
          compDiff <- compDiff[2] - compDiff[1]
          compDiffNum <- compDiff
          compDiff <- ifelse(!is.na(compDiff) && is.numeric(compDiff),
                             paste(round(compDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(compDiffNum)){
            compDiffIcon <- 'small minus icon'
          }else if(compDiffNum > 20){
            compDiffIcon <- 'small angle double up icon'
          }else if(compDiffNum > 0){
            compDiffIcon <- 'small angle up icon'
          }else if(compDiffNum == 0){
            compDiffIcon <- 'small minus icon'
          }else if(compDiffNum < -20){
            compDiffIcon <- 'small angle double down icon'
          }else{
            compDiffIcon <- 'small angle down icon'
          }
        }else{
          compDiff <- '-'
          compDiffIcon <- 'small minus icon'
        }
      }else{
        compDiff <- '-'
        compDiffIcon <- 'small minus icon'
      }
      if(!('agi' %in% colnames(tv$toPlot))){
        tv$toPlot$agi <- NA
      }
      if(length(tv$toPlot$agi[complete.cases(tv$toPlot$agi)]) > 1){
        if(uv$agi_switch == 1){
          tv$toPlot$agi <- repeat.before(tv$toPlot$agi)
          minAgi <- min(min(tv$toPlot$agi, na.rm = T), minScoAgi)
          maxAgi <- max(max(tv$toPlot$agi, na.rm = T), maxScoAgi)
          agiDiff <- round(
                       conv(minAgi, maxAgi, 0, 100,
                            c(head(tv$toPlot$agi[!is.na(tv$toPlot$agi)], 1),
                              tail(tv$toPlot$agi, 1)
                            )
                       ), 2
          )
          agiDiff <- agiDiff[2] - agiDiff[1]
          agiDiffNum <- agiDiff
          agiDiff <- ifelse(!is.na(agiDiff) && is.numeric(agiDiff),
                            paste(round(agiDiff, 2), '%', sep = ''), '0%'
          )
          if(is.na(agiDiffNum)){
            agiDiffIcon <- 'small minus icon'
          }else if(agiDiffNum > 20){
            agiDiffIcon <- 'small angle double up icon'
          }else if(agiDiffNum > 0){
            agiDiffIcon <- 'small angle up icon'
          }else if(agiDiffNum == 0){
            agiDiffIcon <- 'small minus icon'
          }else if(agiDiffNum < -20){
            agiDiffIcon <- 'small angle double down icon'
          }else{
            agiDiffIcon <- 'small angle down icon'
          }
        }else{
          agiDiff <- '-'
          agiDiffIcon <- 'small minus icon'
        }
      }else{
        agiDiff <- '-'
        agiDiffIcon <- 'small minus icon'
      }
    }else{
      cogDiff <- '-'; cogDiffIcon <- 'small orange minus icon'
    }
    
    ## If there is at least some plotted cognition data and the patient has a
    ## cognitive diagnosis from the SLP Eval...
    if(!is.null(tv$toPlot) && !is.na(rv$coggroup)){
      ## If the patient has been diagnosed with aphasia, set up the sidebar
      ## like this.
      if(group == 1){
        output$patStats <- renderUI({
          div(class = 'ui inverted center aligned segment',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste('<span class = orange>', cogDiff, '</span>')),
                      uiicon(cogDiffIcon, style = 'color: #f36b21 !important;')
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px;">
                              &#916 Cognition
                            </span>'
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'com_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                          HTML(paste(ifelse(uv$com_switch == 1,
                                            '<span class = red>',
                                            '<span class = warmgray>'
                                     ), comDiff, '</span>'
                          )),
                          uiicon(comDiffIcon,
                                 style = ifelse(uv$com_switch == 1,
                                                'color: #ed1c2c !important;',
                                                'color: #6e6259 !important;'
                                         )
                          )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Communication
                                </span>'
                          )
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'wcom_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                          HTML(paste(ifelse(uv$wcom_switch == 1,
                                            '<span class = yellow>',
                                            '<span class = warmgray>'
                                     ), wcomDiff, '</span>'
                          )),
                          uiicon(wcomDiffIcon,
                                 style = ifelse(uv$wcom_switch == 1,
                                                'color: #ffd100 !important;',
                                                'color: #6e6259 !important;'
                                         )
                          )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Writing
                                </span>'
                          )
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'comp_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                          HTML(paste(ifelse(uv$comp_switch == 1,
                                            '<span class = purple>',
                                            '<span class = warmgray>'
                                     ), compDiff, '</span>'
                          )),
                          uiicon(compDiffIcon,
                                 style = ifelse(uv$comp_switch == 1,
                                                'color: #6d2077 !important;',
                                                'color: #6e6259 !important;'
                                         )
                          )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Comprehension
                                </span>'
                          )
                      )
                  )
              )
          )
        })
      ## Otherwise, if the patient is in the CCD group, set up the sidebar
      ## like this.
      }else if(group == 2){
        output$patStats <- renderUI({
          div(class = 'ui inverted center aligned segment',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste('<span class = orange>', cogDiff, '</span>')),
                      uiicon(cogDiffIcon, style = 'color: #f36b21 !important;')
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px;">
                              &#916 Cognition
                            </span>'
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'spe_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                          HTML(paste(ifelse(uv$spe_switch == 1,
                                            '<span class = red>',
                                            '<span class = warmgray>'
                                     ), speDiff, '</span>'
                          )),
                          uiicon(speDiffIcon,
                                 style = ifelse(uv$spe_switch == 1,
                                                'color: #ed1c2c !important;',
                                                'color: #6e6259 !important;'
                                         )
                          )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Speech
                                </span>'
                          )
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'mem_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$mem_switch == 1,
                                          '<span class = yellow>',
                                          '<span class = warmgray>'
                                   ), memDiff, '</span>'
                        )),
                        uiicon(memDiffIcon,
                               style = ifelse(uv$mem_switch == 1,
                                              'color: #ffd100 !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Memory
                                </span>'
                          )
                      )
                  )
              )
          )
        })
      ## If the patient is in the CCD-BI group, set up the sidebar like this.
      }else if(group == 3){
        output$patStats <- renderUI({
          div(class = 'ui inverted center aligned segment',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste('<span class = orange>', cogDiff, '</span>')),
                      uiicon(cogDiffIcon, style = 'color: #f36b21 !important;')
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px;">
                              &#916 Cognition
                            </span>'
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'spe_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                          HTML(paste(ifelse(uv$spe_switch == 1,
                                            '<span class = red>',
                                            '<span class = warmgray>'
                                     ), speDiff, '</span>'
                          )),
                          uiicon(speDiffIcon,
                                 style = ifelse(uv$spe_switch == 1,
                                                'color: #ed1c2c !important;',
                                                'color: #6e6259 !important;'
                                         )
                          )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Speech
                                </span>'
                          )
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'mem_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                          HTML(paste(ifelse(uv$mem_switch == 1,
                                            '<span class = yellow>',
                                            '<span class = warmgray>'
                                     ), memDiff, '</span>'
                          )),
                          uiicon(memDiffIcon,
                                 style = ifelse(uv$mem_switch == 1,
                                                'color: #ffd100 !important;',
                                                'color: #6e6259 !important;'
                                         )
                          )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Memory
                                </span>'
                          )
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'agi_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$agi_switch == 1,
                                          '<span class = purple>',
                                          '<span class = warmgray>'
                                   ), agiDiff, '</span>'
                        )),
                        uiicon(agiDiffIcon,
                               style = ifelse(uv$agi_switch == 1,
                                              'color: #6d2077 !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px;">
                                  &#916 Agitation
                                </span>'
                          )
                      )
                  )
              )
          )
        })
      ## If the patient is in the CCD-RHD group, this is how the sidebar should
      ## look.
      }else if(group == 4){
        output$patStats <- renderUI({
          div(class = 'ui inverted center aligned segment',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste('<span class = orange>', cogDiff, '</span>')),
                      uiicon(cogDiffIcon, style = 'color: #f36b21 !important;')
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px;">
                              &#916 Cognition
                            </span>'
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'mem_ad',
                  div(class = 'ui small inverted center aligned statistic',
                      style = 'margin: 0 auto;',
                      div(class = 'center aligned value',
                          HTML(paste(ifelse(uv$mem_switch == 1,
                                            '<span class = yellow>',
                                            '<span class = warmgray>'
                                     ), memDiff, '</span>'
                          )),
                          uiicon(memDiffIcon,
                                 style = ifelse(uv$mem_switch == 1,
                                                'color: #ffd100 !important;',
                                                'color: #6e6259 !important;'
                                         )
                          )
                      ),
                      div(class = 'center aligned label',
                          HTML('<span style = "font-size: 19px">
                                  &#916 Memory
                                </span>'
                          )
                      )
                  )
              )
          )
        })
      ## And finally, if the patient is in the speech disorders group, the
      ## sidebar will look like this.
      }else if(group == 5){
        output$patStats <- renderUI({
          div(class = 'ui inverted center aligned segment',
              div(class = 'ui small inverted center aligned statistic',
                  style = 'margin: 0 auto;',
                  div(class = 'center aligned value',
                      HTML(paste('<span class = orange>', cogDiff, '</span>')),
                      uiicon(cogDiffIcon, style = 'color: #f36b21 !important;')
                  ),
                  div(class = 'center aligned label',
                      HTML('<span style = "font-size: 19px">
                              &#916 Cognition
                            </span>'
                      )
                  )
              ),
              div(class = 'ui divider',
                  style = 'margin-top: 1em; margin-bottom: 1em;'
              ),
              div(class = 'ui button',
                  style = 'height: 100%; width: 100%;
                           background-color: #1B1C1D;',
                  id = 'spe_ad',
                div(class = 'ui small inverted center aligned statistic',
                    style = 'margin: 0 auto;',
                    div(class = 'center aligned value',
                        HTML(paste(ifelse(uv$spe_switch == 1,
                                          '<span class = red>',
                                          '<span class = warmgray>'
                                   ), speDiff, '</span>'
                        )),
                        uiicon(speDiffIcon,
                               style = ifelse(uv$spe_switch == 1,
                                              'color: #ed1c2c !important;',
                                              'color: #6e6259 !important;'
                                       )
                        )
                    ),
                    div(class = 'center aligned label',
                        HTML('<span style = "font-size: 19px;">
                                &#916 Speech
                              </span>'
                        )
                    )
                )
              )
          )
        })
      }
    ## If the patient has no cognition data and/or no cognitive diagnosis,
    ## then just throw out a generic sidebar with no information
    }else{
      output$patStats <- renderUI({
        div(class = 'ui inverted center aligned segment',
            div(class = 'ui small inverted center aligned statistic',
                style = 'margin: 0 auto;',
                div(class = 'center aligned value',
                    HTML(paste('<span class = orange>', cogDiff, '</span>')),
                    uiicon(cogDiffIcon, style = 'color: #f36b21 !important')
                ),
                div(class = 'center aligned label',
                    HTML('<span style = "font-size: 19px;">
                            &#916 Cognition
                          </span>'
                    )
                )
            )
        )
      })
    }
    
    output$patStats2 <- renderUI({
      div(class = 'ui inverted center aligned segment',
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class = orange
                                    style = "font-size: 1.5vw;">',
                                isolate(rv$row$Name),
                             '</span>'
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                                Name
                              </span>'
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class = tooltipSB
                                    aria-label = "',
                                    as.numeric(Sys.Date() - rv$admit),
                                    ' Days Ago"',
                             '>
                                <span class = orange
                                      style = "font-size: 1.5vw;"
                                >',
                                  ifelse(is.na(rv$admit), 'Not recorded',
                                         as.character(rv$admit)
                                  ),
                               '</span>
                             </span>', sep = ''
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                                Admit Date
                              </span>'
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class =',
                                    ifelse(is.na(rv$depart),
                                           'tooltipSB2', 'tooltipSB'
                                    ),
                                    ' aria-label = "',
                                    ifelse(is.na(rv$depart),
                                           '?',
                                           as.numeric(rv$depart - Sys.Date())
                                    ),
                                    ' Days Left"',
                             '>
                                <span class = orange
                                      style = "font-size: 1.5vw;"
                                >',
                                  ifelse(is.na(rv$depart), 'Not recorded',
                                         as.character(rv$depart)
                                  ),
                               '</span>
                              </span>', sep = ''
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                               Depart Date
                              </span>'
                    
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          ),
          div(class = 'ui small inverted center aligned statistic',
              style = 'margin: 0 auto;',
              div(class = 'center aligned value',
                  HTML(paste('<span class = orange
                                    style = "font-size: 1.5vw;">',
                                isolate(rv$row$MedicalService),
                             '</span>'
                  ))
              ),
              div(class = 'center aligned label',
                  HTML(paste('<span class = white style = "font-size: 19px;">
                                Medical Service
                              </span>'
                  ))
              )
          ),
          div(class = 'ui divider',
              style = 'margin-top: 1em; margin-bottom: 0.5em;'
          )
      )
    })
    
  }
  
  ## A function for rendering FIM levels in the Update FIM view.
  scEdit <- function(){
    ## This is what gets rendered within the Self-Care tab of the accordion
    ## on the bottom right of the screen
    output$scEdit <- renderUI({
      div(
          sliderInput('eatN', 'Eating', min = 0, max = 7,
                      value = ifelse(is.na(rv$datSC[1]) ||
                                     isolate(rv$datSC[1]) > 7,
                                     0, rv$datSC[1]
                      )
          ),
          sliderInput('groomN', 'Grooming', min = 0, max = 7,
                      value = ifelse(is.na(rv$datSC[2]) ||
                                     isolate(rv$datSC[2]) > 7,
                                     0, rv$datSC[2]
                      )
          ),
          sliderInput('bathN', 'Bathing', min = 0, max = 7,
                      value = ifelse(is.na(rv$datSC[3]) ||
                                     isolate(rv$datSC[3]) > 7,
                                     0, rv$datSC[3]
                      )
          ),
          sliderInput('ubDressN', 'UB Dressing', min = 0, max = 7,
                      value = ifelse(is.na(rv$datSC[4]) ||
                                     isolate(rv$datSC[4]) > 7, 0,
                                     rv$datSC[4]
                      )
          ),
          sliderInput('lbDressN', 'LB Dressing', min = 0, max = 7,
                      value = ifelse(is.na(rv$datSC[5]) ||
                                     isolate(rv$datSC[5]) > 7,
                                     0, rv$datSC[5]
                      )
          ),
          sliderInput('toiletN', 'Toileting', min = 0, max = 7,
                      value = ifelse(is.na(rv$datSC[6]) ||
                                     isolate(rv$datSC[6]) > 7,
                                     0, rv$datSC[6]
                      )
          )
      )
    })
    ## This is a vital option setting. Without it, the sliders will not be
    ## generated when the SC accordion tab is minimized. 
    outputOptions(output, 'scEdit', suspendWhenHidden = F)
  }
  
  ## Renders FIM levels in the Update FIM view when Mobility is the selected
  ## domain. See above for mark-up.
  mobEdit <- function(){
    output$mobEdit <- renderUI({
      div(
          sliderInput('bcTransN', 'Bed/Chair', min = 0, max = 7,
                      value = ifelse(is.na(rv$datMob[1]) ||
                                     isolate(rv$datMob[1] > 7),
                                     0, rv$datMob[1]
                      )
          ),
          sliderInput('tsTransN', 'Tub/Shower', min = 0, max = 7,
                      value = ifelse(is.na(rv$datMob[2]) ||
                                     isolate(rv$datMob[2] > 7),
                                     0, rv$datMob[2]
                      )
          ),
          sliderInput('tTransN', 'Toilet', min = 0, max = 7,
                      value = ifelse(is.na(rv$datMob[3]) ||
                                     isolate(rv$datMob[3] > 7),
                                     0, rv$datMob[3]
                      )
          ),
          sliderInput('locWalkN', 'Walking', min = 0, max = 7,
                      value = ifelse(is.na(rv$datMob[4]) ||
                                     isolate(rv$datMob[4] > 7),
                                     0, rv$datMob[4]
                      )
          ),
          sliderInput('locWheelN', 'Wheelchair', min = 0, max = 6,
                      value = ifelse(is.na(rv$datMob[5]) ||
                                     isolate(rv$datMob[5] > 7),
                                     0, rv$datMob[5]
                      )
          ),
          sliderInput('locStairN', 'Stairs', min = 0, max = 7,
                      value = ifelse(is.na(rv$datMob[6]) ||
                                     isolate(rv$datMob[6] > 7),
                                     0, rv$datMob[6]
                      )
          )
      )
    })
    outputOptions(output, 'mobEdit', suspendWhenHidden = F)
  }
  
  ## Same as the above two functions, but for the Cognition domain.
  cogEdit <- function(){
    output$cogEdit <- renderUI({
      div(
          sliderInput('compN', 'Comprehension', min = 0, max = 7,
                      value = ifelse(is.na(rv$datCog[1]) ||
                                     isolate(rv$datCog[1]) > 7,
                                     0, rv$datCog[1]
                      )
          ),
          sliderInput('expN', 'Expression', min = 0, max = 7,
                      value = ifelse(is.na(rv$datCog[2]) ||
                                     isolate(rv$datCog[2]) > 7,
                                     0, rv$datCog[2]
                      )
          ),
          sliderInput('siN', 'Social Interaction', min = 0, max = 7,
                      value = ifelse(is.na(rv$datCog[3]) ||
                                     isolate(rv$datCog[3]) > 7,
                                     0, rv$datCog[3]
                      )
          ),
          sliderInput('psN', 'Problem Solving', min = 0, max = 7,
                      value = ifelse(is.na(rv$datCog[4]) ||
                                     isolate(rv$datCog[4]) > 7,
                                     0, rv$datCog[4]
                      )
          ),
          sliderInput('memN', 'Memory', min = 0, max = 7,
                      value = ifelse(is.na(rv$datCog[5]) ||
                                     isolate(rv$datCog[5]) > 7,
                                     0, rv$datCog[5]
                      )
          )
      )
    })
    outputOptions(output, 'cogEdit', suspendWhenHidden = F)
  }
  
  ## Event handler that is triggered when the Update FIM button is clicked.
  ## It records the entered data as a reactive value and invokes
  ## updateHandler3().
  updateFIM <- function(){
    if(uv$dom == 'sc'){
      rv$datSC[1] <- input$eatN
      rv$datSC[2] <- input$groomN
      rv$datSC[3] <- input$bathN
      rv$datSC[4] <- input$ubDressN
      rv$datSC[5] <- input$lbDressN
      rv$datSC[6] <- input$toiletN
      if(any(isolate(rv$datSC) == 0, na.rm = T)){
        rv$datSC[which(rv$datSC == 0)] <- 88
      }
    }
    if(uv$dom == 'mob'){
      rv$datMob[1] <- input$bcTransN
      rv$datMob[2] <- input$tsTransN
      rv$datMob[3] <- input$tTransN
      rv$datMob[4] <- input$locWalkN
      rv$datMob[5] <- input$locWheelN
      rv$datMob[6] <- input$locStairN
      if(any(isolate(rv$datMob) == 0, na.rm = T)){
        rv$datMob[which(rv$datMob == 0)] <- 88
      }
    }
    if(uv$dom == 'cog'){
      rv$datCog[1] <- input$compN
      rv$datCog[2] <- input$expN
      rv$datCog[3] <- input$siN
      rv$datCog[4] <- input$psN
      rv$datCog[5] <- input$memN
      if(any(isolate(rv$datCog) == 0, na.rm = T)){
        rv$datCog[which(rv$datCog == 0)] <- 88
      }
    }
    updateHandler3()
  }
  
  ## Function for creating the FIM Goals plot for the self-care domain. It's
  ## more or less just a simple barplot that shows current, actual, and
  ## expected functional levels for each AQ domain.
  goalPlotSC <- function(){
    ## A check for whether or not the patient has FIM-SC goals
    checkGoals <- if(isolate(rv$fin) %in% fimSCGoals$FIN) 1 else 0
    
    ## If they do, and they also have AQ-SC data...
    if(checkGoals == 1 && !is.null(isolate(rv$scSco[[2]]))){
      ## Pull the patient's AQ scores and create a time variable for it
      isolate(rv$toPlot_goals <- isolate(as.data.frame(rv$scSco[[2]])))
      rv$toPlot_goals$time <- rv$los -
                              as.numeric(
                                Sys.Date() -
                                as.Date(rv$toPlot_goals$assessmentDate)
                              )
      ## Set aside FIM data
      fimScores <- isolate(rv$fimSCO[rv$fimSCO$FIN == isolate(rv$fin), 3:8])
      ## If they have FIM scores on multiple dates...
      if(dim(fimScores)[1] > 1){
        ## Impute the data forward, take the last row, and convert them from
        ## the IRT-ready data into the actual recorded value (by adding 1)
        fimScores <- apply(fimScores, 2, repeat.before)
        fimActual <- tail(fimScores, 1)
        fimActual <- fimActual + 1
      }else{
        ## Otherwise, simply perform the +1 conversion. I'm realizing now that
        ## I could do without the "else."
        fimActual <- as.numeric(fimScores) + 1
      }
      
      ## I'm not sure the conditional here is nessary. I guess I probably
      ## changed the conditional this part is nested in. At this point, we
      ## already know that the patient appears in the fimSCGoals object.
      if(isolate(rv$fin) %in% fimSCGoals$FIN){
        ## Select the patient's FIM-SC goals data and strip it of the
        ## (unnecessary for this segment) assessment date info
        if(is.null(rv$newGoalsSC)){
          fimGoals <- fimSCGoals[fimSCGoals$FIN == isolate(rv$fin), ]
          fimGoals <- fimGoals[, 3:8]
        }else{
          fimGoals <- data.frame(eating = as.numeric(isolate(input$eat)),
                                 grooming = as.numeric(isolate(input$groom)),
                                 bathing = as.numeric(isolate(input$bath)),
                                 dressingUpper = as.numeric(
                                                   isolate(input$ubDress)
                                 ),
                                 dressingLower = as.numeric(
                                                   isolate(input$lbDress)
                                 ),
                                 toileting = as.numeric(isolate(input$toilet))
          )
        }
        ## If the patient has more than one set of goals/modifications to goals
        if(nrow(fimGoals) > 1){
          ## Impute forward and take the most recent set
          fimGoals <- apply(fimGoals, 2, repeat.before)
          fimGoals <- tail(fimGoals, 1)
        }
      }else{
        fimGoals <- rep(NA, 6)
      }
      
      ## Take the patient's AQ-SC scores, then map those scores to the FIM scale
      fimPred <- predGen(mapSco = tail(rv$toPlot$sc, 1),
                         bs = tail(siBalBs, 6)
      ) + 1
      ## Perform the appropriate recoding
      fimPred[2] <- car::recode(fimPred[2], "1=3;2=4;3=5;4=6;5=7")
      fimPred[3] <- car::recode(fimPred[3], "1=1;2=2;3=3;4=4;5=5;6=7")
      fimPred[5] <- car::recode(fimPred[5], "1=2;2=3;3=4;4=5;5=6;6=7")
      fimPred[6] <- car::recode(fimPred[6], "1=1;2=2;3=3;4=4;5=5;6=7")
      
      ## Set up the data.frame to plot. The reason for the seemingly unecessary
      ## use of a factor for the item labels is because plotly thinks everyone
      ## wants alphabetical ordering all the time rather than their literal
      ## ordering. 
      rv$fimPlot <- data.frame(items = factor(
                                         c('Eating', 'Grooming', 'Bathing',
                                           'Dressing - UB', 'Dressing - LB',
                                           'Toileting'
                                         ),
                                         levels = c('Eating', 'Grooming',
                                                    'Bathing', 'Dressing - UB',
                                                    'Dressing - LB',
                                                    'Toileting'
                                                    ),
                                         labels = c('Eating', 'Grooming',
                                                    'Bathing', 'Dressing - UB',
                                                    'Dressing - LB',
                                                    'Toileting'
                                         )
                               ),
                               goals = as.numeric(unname(fimGoals)),
                               actual = as.numeric(unname(fimActual)),
                               predicted = fimPred
      )
      if(any(isolate(rv$fimPlot$goals) == 0, na.rm = T)){
        isolate(rv$fimPlot$goals[which(rv$fimPlot$goals == 0)] <- -1)
      }
      if(any(isolate(rv$fimPlot$actual) > 7, na.rm = T)){
        isolate(rv$fimPlot$actual[which(rv$fimPlot$actual > 7)] <- -1)
      }
      if(any(isolate(rv$fimPlot$goals) == -1, na.rm = T)){
        isolate(rv$fimPlot$gtext <- NA)
        rv$fimPlot$gtext[which(rv$fimPlot$goals == -1)] <- 'Does not occur'
        rv$fimPlot$gtext[is.na(rv$fimPlot$gtext)] <- as.character(
          rv$fimPlot$goals[which(is.na(rv$fimPlot$gtext))]
        )
      }else{
        isolate(rv$fimPlot$gtext <- as.character(rv$fimPlot$goals))
      }
      if(any(isolate(rv$fimPlot$actual) == -1, na.rm = T)){
        isolate(rv$fimPlot$atext <- NA)
        rv$fimPlot$atext[which(rv$fimPlot$actual == -1)] <- 'Does not occur'
        rv$fimPlot$atext[is.na(rv$fimPlot$atext)] <- as.character(
          rv$fimPlot$actual[which(is.na(rv$fimPlot$atext))]
        )
      }else{
        isolate(rv$fimPlot$atext <- as.character(rv$fimPlot$actual))
      }
      isolate(rv$fimPlot$ptext <- as.character(rv$fimPlot$predicted))
      rv$fimPlot$ptext[2] <- ifelse(rv$fimPlot$predicted[2] == 3,
                                    '1, 2, or 3',
                                    rv$fimPlot$ptext[2]
      )
      rv$fimPlot$ptext[c(3, 6)] <- sapply(rv$fimPlot$predicted[c(3, 6)],
                                          function(x) ifelse(x >= 6,
                                                             '6 or 7', x
                                          )
      )
      rv$fimPlot$ptext[5] <- ifelse(rv$fimPlot$predicted[5] == 2,
                                    '1 or 2',
                                    rv$fimPlot$ptext[5]
      )

      ## Create and render the plot. Everything is virtually the same as the
      ## scatter/line plots in the initTC_sc function, except the type is now
      ## a barplot
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          text = ~paste('Current: ', atext),
          hoverinfo = 'text',
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  text = ~paste('Typical: ', ptext),
                  hoverinfo = 'text',
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  text = ~paste('Goal: ', gtext),
                  hoverinfo = 'text',
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            tickangle = -60,
                            type = 'cateogry',
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               yaxis = list(range = c(-0.5, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h',
                             xanchor = 'center',
                             x = .5, y = 1.2,
                             font = list(size = 24)
               ),
               margin = list(b = 175),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
      
    ## Otherwise, if the patient has goals but no AQ scores
    }else if(checkGoals == 1 && is.null(rv$scSco[[2]])){
      ## Select and format the patient's goal data
      if(is.null(rv$newGoalsSC)){
        fimGoals <- fimSCGoals[fimSCGoals$FIN == isolate(rv$fin), ]
        fimGoals <- fimGoals[, 3:8]
      }else{
        fimGoals <- data.frame(eating = isolate(rv$eat),
                               grooming = isolate(rv$groom),
                               bathing = isolate(rv$bath),
                               dressingUpper = isolate(rv$ubDress),
                               dressingLower = isolate(rv$lbDress),
                               toileting = isolate(rv$toilet)
        )
      }
      ## Impute forward if necessary
      if(nrow(fimGoals > 1)){
        fimGoals <- apply(fimGoals, 2, repeat.before)
      }
      ## Take the most recent
      fimGoals <- tail(fimGoals, 1)
      ## Set up the data.frame to plot. Without AQ-SC score, no
      ## predicted/expected or actual FIM levels can be charted
      rv$fimPlot <- data.frame(items = factor(
                                         c('Eating', 'Grooming', 'Bathing',
                                           'Dressing - UB', 'Dressing - LB',
                                           'Toileting'
                                         ),
                                         levels = c('Eating', 'Grooming',
                                                    'Bathing', 'Dressing - UB',
                                                    'Dressing - LB',
                                                    'Toileting'
                                         ),
                                         labels = c('Eating', 'Grooming',
                                                    'Bathing', 'Dressing - UB',
                                                    'Dressing - LB',
                                                    'Toileting'
                                         )
                               ),
                               goals = as.numeric(unname(fimGoals)),
                               actual = NA,
                               predicted = NA
      )
      rv$fimPlot$gtext <- as.character(rv$fimPlot$goals)
      rv$fimPlot$atext <- NA
      rv$fimPlot$ptext <- NA
      
      ## Then construct plot for rendering
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          text = ~paste('Current: ', atext),
          hoverinfo = 'text',
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  text = ~paste('Typical: ', ptext),
                  hoverinfo = 'text',
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  text = ~paste('Goal: ', gtext),
                  hoverinfo = 'text',
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            tickangle = -60,
                            type = 'category',
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               yaxis = list(range = c(0, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h',
                             xanchor = 'center',
                             x = .5, y = 1.2,
                             font = list(size = 24)
               ),
               margin = list(b = 175),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
    ## Otherwise, if there's nothing at all, just create an empty plot
    }else{
      
      rv$fimPlot <- data.frame(items = factor(
                                         c('Eating', 'Grooming', 'Bathing',
                                           'Dressing - UB', 'Dressing - LB',
                                           'Toileting'
                                         ),
                                         levels = c('Eating', 'Grooming',
                                                    'Bathing', 'Dressing - UB',
                                                    'Dressing - LB',
                                                    'Toileting'
                                         ),
                                         labels = c('Eating', 'Grooming',
                                                    'Bathing', 'Dressing - UB',
                                                    'Dressing - LB',
                                                    'Toileting'
                                         )
                               ),
                               goals = rep(0, 6),
                               actual = rep(0, 6),
                               predicted = rep(0, 6)
      )
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(~items,
                  y = ~predicted,
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(~items,
                  y = ~goals,
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            tickangle = -60,
                            type = 'category',
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               yaxis = list(range = c(0, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h',
                             xanchor = 'center',
                             x = .5, y = 1.2,
                             font = list(size = 24)
               ),
               margin = list(b = 175),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
    }
    
    ## Now that the appropriate plot has been made with the available data,
    ## output it in a div
    output$patGoals <- renderUI({
      div(style = 'border-radius: .28571429rem;',
        plotlyOutput('patFIM', height = '700px')
      )
    })
  }
  
  ## The mobility version of the goal plot (see goalPlotSC for mark-up).
  goalPlotMob <- function(){
    checkGoals <- if(isolate(rv$fin) %in% fimMobGoals$FIN) 1 else 0
    
    if(checkGoals == 1 && !is.null(isolate(rv$mobSco[[2]]))){
      rv$toPlot_goals <- isolate(as.data.frame(rv$mobSco[[2]]))
      rv$toPlot_goals$time <- rv$los -
                              as.numeric(Sys.Date() -
                                         as.Date(
                                           rv$toPlot_goals$assessmentDate
                                         )
                              )
      
      fimScores <- rv$fimMobO[which(rv$fimMobO$FIN == isolate(rv$fin)), 3:8]
      if(dim(fimScores)[1] > 1){
        fimScores <- apply(fimScores, 2, repeat.before)
        fimActual <- tail(fimScores, 1)
        fimActual <- fimActual + 1
      }else{
        fimActual <- as.numeric(fimScores) + 1
      }
      if(isolate(rv$fin) %in% fimMobGoals$FIN){
        if(is.null(rv$newGoalsMob)){
          fimGoals <- fimMobGoals[fimMobGoals$FIN == isolate(rv$fin), ]
          fimGoals <- fimGoals[, 3:8]
        }else{
          fimGoals <- data.frame(bedChairTransfer = as.numeric(
                                                      isolate(input$bcTrans)
                                 ),
                                 tubShowerTransfer = as.numeric(
                                                       isolate(input$tsTrans)
                                 ),
                                 toiletTransfer = as.numeric(
                                                    isolate(input$tTrans)
                                 ),
                                 locomotionWalk = as.numeric(
                                                   isolate(input$locWalk)
                                 ),
                                 locomotionWheelchair = as.numeric(
                                                          isolate(
                                                            input$locWheel
                                                          )
                                 ),
                                 locomotionStairs = as.numeric(
                                                      isolate(input$locStairs)
                                 )
          )
        }
        if(nrow(fimGoals) > 1){
          fimGoals <- apply(fimGoals, 2, repeat.before)
          fimGoals <- tail(fimGoals, 1)
        }
      }else{
        fimGoals <- rep(NA, 6)
      }
      
      if(isolate(rv$mobgroup) == 1){
        fimPred <- predGen(mapSco = isolate(tail(rv$toPlot$mob, 1)),
                           bs = tail(wheelBs, 4)
        ) + 1
        fimPred <- c(fimPred[1:3], NA, fimPred[4], NA)
      }else if(isolate(rv$mobgroup %in% c(2, 3))){
        fimPred <- predGen(mapSco = isolate(tail(rv$toPlot$mob, 1)),
                           bs = tail(bothBs, 6)
        ) + 1
      }
      fimPred[2] <- car::recode(fimPred[2], "1=1;2=2;3=3;4=4;5=5;6=7")
      
      rv$fimPlot <- data.frame(
                      items = factor(
                                c('Bed/Chair Transfer', 'Tub/Shower Transfer',
                                  'Toilet Transfer', 'Locomotion - Walk',
                                  'Locomotion - Wheel', 'Locomotion - Stairs'
                                ),
                                levels = c('Bed/Chair Transfer',
                                           'Tub/Shower Transfer',
                                           'Toilet Transfer',
                                           'Locomotion - Walk',
                                           'Locomotion - Wheel',
                                           'Locomotion - Stairs'
                                ),
                                labels = c('Bed/Chair Transfer',
                                           'Tub/Shower Transfer',
                                           'Toilet Transfer',
                                           'Locomotion - Walk',
                                           'Locomotion - Wheel',
                                           'Locomotion - Stairs'
                                )
                              ),
                      goals = as.numeric(unname(fimGoals)),
                      actual = as.numeric(unname(fimActual)),
                      predicted = fimPred
      )
      if(any(isolate(rv$fimPlot$goals) == 0, na.rm = T)){
        isolate(rv$fimPlot$goals[which(rv$fimPlot$goals == 0)] <- -1)
      }
      if(any(isolate(rv$fimPlot$actual) > 7, na.rm = T)){
        isolate(rv$fimPlot$actual[which(rv$fimPlot$actual > 7)] <- -1)
      }
      if(any(isolate(rv$fimPlot$goals) == -1, na.rm = T)){
        isolate(rv$fimPlot$gtext <- NA)
        rv$fimPlot$gtext[which(rv$fimPlot$goals == -1)] <- 'Does not occur'
        rv$fimPlot$gtext[is.na(rv$fimPlot$gtext)] <- as.character(
          rv$fimPlot$goals[which(is.na(rv$fimPlot$gtext))]
        )
      }else{
        isolate(rv$fimPlot$gtext <- as.character(rv$fimPlot$goals))
      }
      if(any(isolate(rv$fimPlot$actual) == -1, na.rm = T)){
        isolate(rv$fimPlot$atext <- NA)
        rv$fimPlot$atext[which(rv$fimPlot$actual == -1)] <- 'Does not occur'
        rv$fimPlot$atext[is.na(rv$fimPlot$atext)] <- as.character(
          rv$fimPlot$actual[which(is.na(rv$fimPlot$atext))]
        )
      }else{
        isolate(rv$fimPlot$atext <- as.character(rv$fimPlot$actual))
      }
      isolate(rv$fimPlot$ptext <- as.character(rv$fimPlot$predicted))
      rv$fimPlot$ptext[2] <- ifelse(rv$fimPlot$predicted[2] == 6,
                                    '6 or 7',
                                    rv$fimPlot$ptext[2]
      )
      rv$fimPlot$ptext[3] <- ifelse(rv$fimPlot$predicted[3] == 6,
                                    '6 or 7',
                                    rv$fimPlot$ptext[3]
      )
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          text = ~paste('Current: ', atext),
          hoverinfo = 'text',
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  text = ~paste('Typical: ', ptext),
                  hoverinfo = 'text',
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  text = ~paste('Goal: ', gtext),
                  hoverinfo = 'text',
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            type = 'category',
                            tickangle = -60,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               yaxis = list(range = c(-0.5, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h',
                             xanchor = 'center',
                             x = .5, y = 1.2,
                             font = list(size = 24)
               ),
               margin = list(b = 250),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }else if(checkGoals == 1 && is.null(rv$mobSco[[2]])){
      fimGoals <- fimMobGoals[fimMobGoals$FIN == isolate(rv$fin), ]
      fimGoals <- fimGoals[, 3:8]
      if(nrow(fimGoals > 1)){
        fimGoals <- apply(fimGoals, 2, repeat.before)
      }
      fimGoals <- tail(fimGoals, 1)
      rv$fimPlot <- data.frame(
                      items = factor(
                                c('Bed/Chair Transfer', 'Tub/Shower Transfer',
                                  'Toilet Transfer', 'Locomotion - Walk',
                                  'Locomotion - Wheel', 'Locomotion - Stairs'
                                ),
                                levels = c('Bed/Chair Transfer',
                                           'Tub/Shower Transfer',
                                           'Toilet Transfer',
                                           'Locomotion - Walk',
                                           'Locomotion - Wheel',
                                           'Locomotion - Stairs'
                                ),
                                labels = c('Bed/Chair Transfer',
                                           'Tub/Shower Transfer',
                                           'Toilet Transfer',
                                           'Locomotion - Walk',
                                           'Locomotion - Wheel',
                                           'Locomotion - Stairs'
                                )
                      ),
                      goals = as.numeric(unname(fimGoals)),
                      actual = NA,
                      predicted = NA
      )
      rv$fimPlot$gtext <- as.character(rv$fimPlot$goals)
      rv$fimPlot$atext <- NA
      rv$fimPlot$ptext <- NA
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          text = ~paste('Current: ', atext),
          hoverinfo = 'text',
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  text = ~paste('Typical: ', ptext),
                  hoverinfo = 'text',
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  text = ~paste('Goal: ', gtext),
                  hoverinfo = 'text',
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            tickangle = -60,
                            type = 'category',
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               yaxis = list(range = c(0, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h',
                             xanchor = 'center',
                             x = .5, y = 1.2,
                             font = list(size = 24)
               ),
               margin = list(b = 250),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }else{
      rv$fimPlot <- data.frame(
                      items = factor(
                                c('Bed/Chair Transfer', 'Tub/Shower Transfer',
                                  'Toilet Transfer', 'Locomotion - Walk',
                                  'Locomotion - Wheel', 'Locomotion - Stairs'
                                ),
                                levels = c('Bed/Chair Transfer',
                                           'Tub/Shower Transfer',
                                           'Toilet Transfer',
                                           'Locomotion - Walk',
                                           'Locomotion - Wheel',
                                           'Locomotion - Stairs'
                                ),
                                labels = c('Bed/Chair Transfer',
                                           'Tub/Shower Transfer',
                                           'Toilet Transfer',
                                           'Locomotion - Walk',
                                           'Locomotion - Wheel',
                                           'Locomotion - Stairs'
                                )
                              ),
                      goals = rep(0, 6),
                      actual = rep(0, 6),
                      predicted = rep(0, 6)
      )
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            tickangle = -60,
                            type = 'category',
                            titlefont = list(size = 24),
                            tickfont = list(size = 24)),
               yaxis = list(range = c(0, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            titlefont = list(size = 24),
                            tickfont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h',
                             xanchor = 'center',
                             x = .5, y = 1.2,
                             font = list(size = 24)
               ),
               margin = list(b = 250),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }
  }
  
  ## The cognition version of the goal plot (see goalPlotSC for mark-up).
  goalPlotCog <- function(){
    checkGoals <- if(isolate(rv$fin) %in% fimCogGoals$FIN) 1 else 0
    
    if(checkGoals == 1 && !is.null(isolate(rv$cogSco[[2]]))){
      rv$toPlot_goals <- isolate(as.data.frame(isolate(rv$cogSco[[2]])))
      rv$toPlot_goals$time <- rv$los -
                              as.numeric(
                                Sys.Date() -
                                as.Date(rv$toPlot_goals$assessmentDate)
                              )

      isolate(
      if(!is.na(rv$coggroup)){
        if(isolate(rv$coggroup) == 1){
          rv$toPlot_goals$spe <- NA
          rv$toPlot_goals$mem <- NA
          rv$toPlot_goals$agi <- NA
        }else if(isolate(rv$coggroup) == 2){
          rv$toPlot_goals$com <- NA
          rv$toPlot_goals$wcom <- NA
          rv$toPlot_goals$comp <- NA
          rv$toPlot_goals$agi <- NA
        }else if(isolate(rv$coggroup) == 3){
          rv$toPlot_goals$com <- NA
          rv$toPlot_goals$wcom <- NA
          rv$toPlot_goals$comp <- NA
        }else if(isolate(rv$coggroup) == 4){
          rv$toPlot_goals$spe <- NA
          rv$toPlot_goals$com <- NA
          rv$toPlot_goals$wcom <- NA
          rv$toPlot_goals$comp <- NA
          rv$toPlot_goals$agi <- NA
        }else if(isolate(rv$coggroup) == 5){
          rv$toPlot_goals$mem <- NA
          rv$toPlot_goals$com <- NA
          rv$toPlot_goals$wcom <- NA
          rv$toPlot_goals$comp <- NA
          rv$toPlot_goals$agi <- NA
        }
      }
      )
      
      fimScores <- rv$fimCogO[which(rv$fimCogO$FIN == isolate(rv$fin)), 3:7]
      fimScores <- apply(fimScores, 2, as.numeric)
      if(class(fimScores) == 'numeric'){
        fimScores <- t(data.frame(fimScores))
      }else if(class(fimScores) == 'matrix'){
        fimScores <- as.data.frame(fimScores)
      }
      if(dim(fimScores)[1] > 1){
        fimScores <- apply(fimScores, 2, repeat.before)
        fimActual <- tail(fimScores, 1)
        fimActual <- fimActual + 1
      }else{
        fimActual <- fimScores + 1
      }
      
      if(isolate(rv$fin) %in% fimCogGoals$FIN){
        if(is.null(rv$newGoalsCog)){
          fimGoals <- fimCogGoals[fimCogGoals$FIN == isolate(rv$fin), ]
          fimGoals <- fimGoals[, 3:7]
        }else{
          fimGoals <- data.frame(comprehension = as.numeric(
                                                   isolate(input$comp)
                                 ),
                                 expression = as.numeric(isolate(input$exp)),
                                 socialInteraction = as.numeric(
                                                       isolate(input$si)
                                 ),
                                 problemSolving = as.numeric(
                                                    isolate(input$ps)
                                 ),
                                 memory = as.numeric(isolate(input$mem))
          )
        }
        if(nrow(fimGoals) > 1){
          fimGoals <- apply(fimGoals, 2, repeat.before)
          fimGoals <- tail(fimGoals, 1)
        }
      }else{
        fimGoals <- rep(NA, 5)
      }
      
      if(!is.na(isolate(rv$coggroup))){
        fimPred <- predGen(mapSco = tail(isolate(rv$toPlot_goals$cog), 1),
                           bs = tail(aphBs, 5)
        ) + 1
      }else{
        fimPred <- rep(NA, 5)
      }
      
      if(length(fimActual) == 0){
        fimActual <- rep(NA, 5)
      }
      
      rv$fimPlot <- data.frame(items = factor(
                                         c('Comprehension', 'Expression',
                                           'Social Interaction',
                                           'Problem Solving', 'Memory'
                                         ),
                                         levels = c('Comprehension',
                                                    'Expression',
                                                    'Social Interaction',
                                                    'Problem Solving',
                                                    'Memory'
                                         ),
                                         labels = c('Comprehension',
                                                    'Expression',
                                                    'Social Interaction',
                                                    'Problem Solving',
                                                    'Memory'
                                         )
                               ),
                               goals = as.numeric(unname(fimGoals)),
                               actual = as.numeric(unname(fimActual)),
                               predicted = fimPred
      )
      isolate(rv$fimPlot$gtext <- as.character(rv$fimPlot$goals))
      if(any(isolate(rv$fimPlot$goals) == 0, na.rm = T)){
        isolate(rv$fimPlot$goals[which(rv$fimPlot$goals == 0)] <- -1)
      }
      if(any(isolate(rv$fimPlot$actual) > 7, na.rm = T)){
        isolate(rv$fimPlot$actual[which(rv$fimPlot$actual > 7)] <- -1)
      }
      if(any(isolate(rv$fimPlot$goals) == -1, na.rm = T)){
        isolate(rv$fimPlot$gtext <- NA)
        rv$fimPlot$gtext[which(rv$fimPlot$goals == -1)] <- 'Does not occur'
        rv$fimPlot$gtext[is.na(rv$fimPlot$gtext)] <- as.character(
          rv$fimPlot$goals[which(is.na(rv$fimPlot$gtext))]
        )
      }else{
        isolate(rv$fimPlot$gtext <- as.character(rv$fimPlot$goals))
      }
      if(any(isolate(rv$fimPlot$actual) == -1, na.rm = T)){
        isolate(rv$fimPlot$atext <- NA)
        rv$fimPlot$atext[which(rv$fimPlot$actual == -1)] <- 'Does not occur'
        rv$fimPlot$atext[is.na(rv$fimPlot$atext)] <- as.character(
          rv$fimPlot$actual[which(is.na(rv$fimPlot$atext))]
        )
      }else{
        isolate(rv$fimPlot$atext <- as.character(rv$fimPlot$actual))
      }
      isolate(rv$fimPlot$ptext <- as.character(rv$fimPlot$predicted))
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
                type = 'bar',
                x = ~items,
                y = ~actual,
                text = ~paste('Current: ', atext),
                hoverinfo = 'text',
                name = 'Current',
                marker = list(color = col[4])
        ) %>%
          add_trace(x = ~items,
                    y = ~predicted,
                    text = ~paste('Typical: ', ptext),
                    hoverinfo = 'text',
                    name = 'Typical for AQ Score',
                    marker = list(color = col[5])
          ) %>%
          add_trace(x = ~items,
                    y = ~goals,
                    text = ~paste('Goal: ', gtext),
                    hoverinfo = 'text',
                    name = 'Goal',
                    marker = list(color = col[8])
          ) %>%
          layout(xaxis = list(title = '',
                              tickangle = -60,
                              type = 'category',
                              tickfont = list(size = 24),
                              titlefont = list(size = 24)),
                 yaxis = list(range = c(-0.5, 7),
                              title = 'Functional Categories',
                              autotick = F,
                              dtick = 1,
                              tickfont = list(size = 24),
                              titlefont = list(size = 24)),
                 barmode = 'group',
                 legend = list(orientation = 'h',
                               xanchor = 'center',
                               x = .5, y = 1.2,
                               font = list(size = 24)
                 ),
                 margin = list(b = 200),
                 autosize = T,
                 hoverlabel = list(font = list(size = 24))
          )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }else if(checkGoals == 1 && is.null(isolate(rv$cogSco)[[2]])){
      fimGoals <- fimCogGoals[fimCogGoals$FIN == isolate(rv$fin), ]
      fimGoals <- fimGoals[, 3:7]
      if(nrow(fimGoals > 1)){
        fimGoals <- apply(fimGoals, 2, repeat.before)
      }
      fimGoals <- tail(fimGoals, 1)
      if(isolate(rv$fin) %in% fimCogO$FIN){
        fimScores <- rv$fimCogO[which(rv$fimCogO$FIN == isolate(rv$fin)), 3:7]
        fimScores <- apply(fimScores, 2, as.numeric)
        if(class(fimScores) == 'numeric'){
          fimScores <- t(data.frame(fimScores))
        }else if(class(fimScores) == 'matrix'){
          fimScores <- as.data.frame(fimScores)
        }
        if(dim(fimScores)[1] > 1){
          fimScores <- apply(fimScores, 2, repeat.before)
          fimActual <- tail(fimScores, 1)
          fimActual <- fimActual + 1
        }else{
          fimActual <- fimScores + 1
        }
      }else{
        fimActual <- rep(NA, 5)
      }
      rv$fimPlot <- data.frame(
                      items = factor(
                                c('Comprehension', 'Expression',
                                  'Social Interaction', 'Problem Solving',
                                  'Memory'
                                ),
                                levels = c('Comprehension', 'Expression',
                                           'Social Interaction',
                                           'Problem Solving', 'Memory'
                                ),
                                labels = c('Comprehension', 'Expression',
                                           'Social Interaction',
                                           'Problem Solving',
                                           'Memory'
                                )
                      ),
                      goals = as.numeric(unname(fimGoals)),
                      actual = as.numeric(unname(fimActual)),
                      predicted = NA
      )
      
      isolate(rv$fimPlot$gtext <- as.character(rv$fimPlot$goals))
      if(any(isolate(rv$fimPlot$goals) == 0, na.rm = T)){
        isolate(rv$fimPlot$goals[which(rv$fimPlot$goals == 0)] <- -1)
      }
      if(any(isolate(rv$fimPlot$actual) > 7, na.rm = T)){
        isolate(rv$fimPlot$actual[which(rv$fimPlot$actual > 7)] <- -1)
      }
      if(any(isolate(rv$fimPlot$goals) == -1, na.rm = T)){
        isolate(rv$fimPlot$gtext <- NA)
        rv$fimPlot$gtext[which(rv$fimPlot$goals == -1)] <- 'Does not occur'
        rv$fimPlot$gtext[is.na(rv$fimPlot$gtext)] <- as.character(
          rv$fimPlot$goals[which(is.na(rv$fimPlot$gtext))]
        )
      }else{
        isolate(rv$fimPlot$gtext <- as.character(rv$fimPlot$goals))
      }
      if(any(isolate(rv$fimPlot$actual) == -1, na.rm = T)){
        isolate(rv$fimPlot$atext <- NA)
        rv$fimPlot$atext[which(rv$fimPlot$actual == -1)] <- 'Does not occur'
        rv$fimPlot$atext[is.na(rv$fimPlot$atext)] <- as.character(
          rv$fimPlot$actual[which(is.na(rv$fimPlot$atext))]
        )
      }else{
        isolate(rv$fimPlot$atext <- as.character(rv$fimPlot$actual))
      }
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
                type = 'bar',
                x = ~items,
                y = ~actual,
                text = ~paste('Current: ', atext),
                hoverinfo = 'text',
                name = 'Current',
                marker = list(color = col[4])
        ) %>%
          add_trace(x = ~items,
                    y = ~predicted,
                    name = 'Typical for AQ Score',
                    marker = list(color = col[5]),
                    text = rep('SLP Eval not complete', 5),
                    hoverinfo = 'text'
          ) %>%
          add_trace(x = ~items,
                    y = ~goals,
                    name = 'Goal',
                    text = ~paste('Goal: ', gtext),
                    hoverinfo = 'text',
                    marker = list(color = col[8])
          ) %>%
          layout(xaxis = list(title = '',
                              tickangle = -60,
                              type = 'category',
                              tickfont = list(size = 24),
                              titlefont = list(size = 24)),
                 yaxis = list(range = c(0, 7),
                              title = 'Functional Categories',
                              autotick = F,
                              dtick = 1,
                              tickfont = list(size = 24),
                              titlefont = list(size = 24)),
                 barmode = 'group',
                 legend = list(orientation = 'h',
                               xanchor = 'center',
                               x = .5, y = 1.2,
                               font = list(size = 24)
                 ),
                 margin = list(b = 200),
                 autosize = T,
                 hoverlabel = list(font = list(size = 24))
          )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }else{
      rv$fimPlot <- data.frame(
                      items = factor(
                                c('Comprehension', 'Expression',
                                  'Social Interaction', 'Problem Solving',
                                  'Memory'
                                ),
                                levels = c('Comprehension', 'Expression',
                                           'Social Interaction',
                                           'Problem Solving', 'Memory'
                                ),
                                labels = c('Comprehension', 'Expression',
                                           'Social Interaction',
                                           'Problem Solving', 'Memory'
                                )
                              ),
                      goals = rep(0, 5),
                      actual = rep(0, 5),
                      predicted = rep(0, 5)
      )
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(rv$fimPlot),
                type = 'bar',
                x = ~items,
                y = ~actual,
                name = 'Current',
                marker = list(color = col[4])
        ) %>%
          add_trace(x = ~items,
                    y = ~predicted,
                    name = 'Typical for AQ Score',
                    marker = list(color = col[5])
          ) %>%
          add_trace(x = ~items,
                    y = ~goals,
                    name = 'Goal',
                    marker = list(color = col[8])
          ) %>%
          layout(xaxis = list(title = '',
                              type = 'category',
                              tickangle = -60,
                              tickfont = list(size = 24),
                              titlefont = list(size = 24)),
                 yaxis = list(range = c(0, 7),
                              title = 'Functional Categories',
                              autotick = F,
                              dtick = 1,
                              tickfont = list(size = 24),
                              titlefont = list(size = 24)),
                 barmode = 'group',
                 legend = list(orientation = 'h',
                               xanchor = 'center',
                               x = .5, y = 1.2,
                               font = list(size = 24)
                 ),
                 margin = list(b = 200),
                 autosize = T,
                 hoverlabel = list(font = list(size = 24))
          )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }

  }
  
  ## This function was created purely out of frustration. While the SC and Cog
  ## goal plots seem to update without any apparent issues, the Mob one does
  ## not. This is admittedly a dumb solution, but it works.
  goalPlotMob_update <- function(){
    pv$mobgroup <- as.numeric(input$walkLevel)
    
    checkGoals <- if(isolate(rv$fin) %in% fimMobGoals$FIN) 1 else 0
    
    if(checkGoals == 1 && !is.null(isolate(rv$mobSco[[2]]))){
      pv$toPlot_goals <- isolate(as.data.frame(rv$mobSco[[2]]))
      pv$toPlot_goals$time <- rv$los -
                              as.numeric(
                                Sys.Date() -
                                as.Date(pv$toPlot_goals$assessmentDate)
                              )
      
      fimScores <- fimMob[which(fimMob$FIN == isolate(rv$fin)), 3:8]
      if(dim(fimScores)[1] > 1){
        fimScores <- apply(fimScores, 2, repeat.before)
        fimActual <- tail(fimScores, 1)
        fimActual <- fimActual + 1
      }else{
        fimActual <- as.numeric(fimScores) + 1
      }
      
      if(isolate(rv$fin) %in% fimMobGoals$FIN){
        if(is.null(rv$newGoalsMob)){
          fimGoals <- fimMobGoals[fimMobGoals$FIN == isolate(rv$fin), ]
          fimGoals <- fimGoals[, 3:8]
        }else{
          fimGoals <- data.frame(bedChairTransfer = as.numeric(
                                                      isolate(input$bcTrans)
                                 ),
                                 tubShowerTransfer = as.numeric(
                                                       isolate(input$tsTrans)
                                 ),
                                 toiletTransfer = as.numeric(
                                                    isolate(input$tTrans)
                                 ),
                                 locomotionWalk = as.numeric(
                                                   isolate(input$locWalk)
                                 ),
                                 locomotionWheelchair = as.numeric(
                                                          isolate(
                                                            input$locWheel
                                                          )
                                 ),
                                 locomotionStairs = as.numeric(
                                                      isolate(input$locStairs)
                                 )
          )
        }                           
        if(nrow(fimGoals > 1)){
          fimGoals <- apply(fimGoals, 2, repeat.before)
        }
        fimGoals <- tail(fimGoals, 1)
        # fimGoals <- fimGoals[,c(1, 3, 2, 4:6)]
      }else{
        fimGoals <- rep(NA, 6)
      }
      
      if(isolate(pv$mobgroup) == 1){
        fimPred <- predGen(mapSco = isolate(tail(rv$toPlot$mob, 1)),
                           bs = tail(wheelBs, 4)
        ) + 1
        fimPred <- c(fimPred[1:3], NA, fimPred[4], NA)
      }else if(isolate(pv$mobgroup %in% c(2, 3))){
        fimPred <- predGen(mapSco = isolate(tail(rv$toPlot$mob, 1)),
                           bs = tail(bothBs, 6)
        ) + 1
      }
      fimPred[2] <- car::recode(fimPred[2], "1=1;2=2;3=3;4=4;5=5;6=7")
      
      isolate(
      pv$fimPlot <- data.frame(items = factor(c('Bed/Chair Transfer',
                                                'Tub/Shower Transfer',
                                                'Toilet Transfer',
                                                'Locomotion - Walk',
                                                'Locomotion - Wheel',
                                                'Locomotion - Stairs'
                                              ),
                                              levels = c('Bed/Chair Transfer',
                                                         'Tub/Shower Transfer',
                                                         'Toilet Transfer',
                                                         'Locomotion - Walk',
                                                         'Locomotion - Wheel',
                                                         'Locomotion - Stairs'
                                              ),
                                              labels = c('Bed/Chair Transfer',
                                                         'Tub/Shower Transfer',
                                                         'Toilet Transfer',
                                                         'Locomotion - Walk',
                                                         'Locomotion - Wheel',
                                                         'Locomotion - Stairs'
                                              )
                               ),
                               goals = as.numeric(unname(fimGoals)),
                               actual = as.numeric(unname(fimActual)),
                               predicted = fimPred
      )
      )
      if(any(isolate(pv$fimPlot$actual) > 7, na.rm = T)){
        isolate(pv$fimPlot$actual[which(pv$fimPlot$actual > 7)] <- -1)
      }
      isolate(pv$fimPlot$gtext <- as.character(pv$fimPlot$goals))
      if(any(isolate(pv$fimPlot$actual) == -1, na.rm = T)){
        isolate(pv$fimPlot$atext <- NA)
        pv$fimPlot$atext[which(pv$fimPlot$actual == -1)] <- 'Does not occur'
        pv$fimPlot$atext[is.na(pv$fimPlot$atext)] <- as.character(
                                                       pv$fimPlot$actual[
                                                         which(
                                                           is.na(
                                                             pv$fimPlot$atext
                                                           )
                                                         )
                                                       ]
        )
      }else{
        isolate(pv$fimPlot$atext <- as.character(pv$fimPlot$actual))
      }
      isolate(pv$fimPlot$gtext <- as.character(pv$fimPlot$goals))
      isolate(pv$fimPlot$atext <- as.character(pv$fimPlot$actual))
      isolate(pv$fimPlot$ptext <- as.character(pv$fimPlot$predicted))
      pv$fimPlot$ptext[2] <- ifelse(pv$fimPlot$predicted[2] == 6,
                                    '6 or 7', pv$fimPlot$ptext[2]
      )
      pv$fimPlot$ptext[3] <- ifelse(pv$fimPlot$predicted[3] == 6,
                                    '6 or 7', pv$fimPlot$ptext[3]
      )
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(pv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          text = ~paste('Current: ', atext),
          hoverinfo = 'text',
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  text = ~paste('Typical: ', ptext),
                  hoverinfo = 'text',
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  text = ~paste('Goal: ', gtext),
                  hoverinfo = 'text',
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            type = 'category',
                            tickangle = -60,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               yaxis = list(range = c(-0.5, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h', xanchor = 'center',
                             x = .5, y = 1.2, font = list(size = 24)
               ),
               margin = list(b = 250),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }else if(checkGoals == 1 && is.null(rv$mobSco[[2]])){
      fimGoals <- fimMobGoals[fimMobGoals$FIN == isolate(rv$fin), ]
      fimGoals <- fimGoals[, 3:8]
      if(nrow(fimGoals > 1)){
        fimGoals <- apply(fimGoals, 2, repeat.before)
      }
      fimGoals <- tail(fimGoals, 1)
      pv$fimPlot <- data.frame(items = factor(c('Bed/Chair Transfer',
                                                'Tub/Shower Transfer',
                                                'Toilet Transfer',
                                                'Locomotion - Walk',
                                                'Locomotion - Wheel',
                                                'Locomotion - Stairs'
                                              ),
                                              levels = c('Bed/Chair Transfer',
                                                         'Tub/Shower Transfer',
                                                         'Toilet Transfer',
                                                         'Locomotion - Walk',
                                                         'Locomotion - Wheel',
                                                         'Locomotion - Stairs'
                                              ),
                                              labels = c('Bed/Chair Transfer',
                                                         'Tub/Shower Transfer',
                                                         'Toilet Transfer',
                                                         'Locomotion - Walk',
                                                         'Locomotion - Wheel',
                                                         'Locomotion - Stairs'
                                              )
                               ),
                               goals = as.numeric(unname(fimGoals)),
                               actual = NA,
                               predicted = NA
      )
      pv$fimPlot$gtext <- as.character(pv$fimPlot$goals)
      pv$fimPlot$atext <- NA
      pv$fimPlot$ptext <- NA
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(pv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          text = ~paste('Current: ', atext),
          hoverinfo = 'text',
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  text = ~paste('Typical: ', ptext),
                  hoverinfo = 'text',
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  text = ~paste('Goal: ', gtext),
                  hoverinfo = 'text',
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            tickangle = -60,
                            type = 'category',
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               yaxis = list(range = c(0, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            tickfont = list(size = 24),
                            titlefont = list(size = 24)),
               barmode = 'group',
               legend = list(orientation = 'h', xanchor = 'center',
                             x = .5, y = 1.2, font = list(size = 24)
               ),
               margin = list(b = 250),
               autosize = T,
               hoverlabel = list(font = list(size = 24))
        )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }else{
      pv$fimPlot <- data.frame(items = factor(c('Bed/Chair Transfer',
                                                'Tub/Shower Transfer',
                                                'Toilet Transfer',
                                                'Locomotion - Walk',
                                                'Locomotion - Wheel',
                                                'Locomotion - Stairs'
                                              ),
                                              levels = c('Bed/Chair Transfer',
                                                         'Tub/Shower Transfer',
                                                         'Toilet Transfer',
                                                         'Locomotion - Walk',
                                                         'Locomotion - Wheel',
                                                         'Locomotion - Stairs'
                                              ),
                                              labels = c('Bed/Chair Transfer',
                                                         'Tub/Shower Transfer',
                                                         'Toilet Transfer',
                                                         'Locomotion - Walk',
                                                         'Locomotion - Wheel',
                                                         'Locomotion - Stairs'
                                              )
                               ),
                               goals = rep(0, 6),
                               actual = rep(0, 6),
                               predicted = rep(0, 6)
      )
      
      output$patFIM <- renderPlotly({
        plot_ly(isolate(pv$fimPlot),
          type = 'bar',
          x = ~items,
          y = ~actual,
          name = 'Current',
          marker = list(color = col[4])
      ) %>%
        add_trace(x = ~items,
                  y = ~predicted,
                  name = 'Typical for AQ Score',
                  marker = list(color = col[5])
        ) %>%
        add_trace(x = ~items,
                  y = ~goals,
                  name = 'Goal',
                  marker = list(color = col[8])
        ) %>%
        layout(xaxis = list(title = '',
                            tickangle = -60,
                            type = 'category',
                            titlefont = list(size = 20),
                            tickfont = list(size = 18)),
               yaxis = list(range = c(0, 7),
                            title = 'Functional Categories',
                            autotick = F,
                            dtick = 1,
                            titlefont = list(size = 20),
                            tickfont = list(size = 18)),
               barmode = 'group',
               legend = list(orientation = 'h', xanchor = 'center',
                             x = .5, y = 1.2, font = list(size = 16)
               ),
               margin = list(b = 175),
               autosize = T,
               hoverlabel = list(font = list(size = 16))
        )
      })
      output$patGoals <- renderUI({
        div(style = 'border-radius: .28571429rem;',
          plotlyOutput('patFIM', height = '700px')
        )
      })
    }
  }
  
  ## Converts IRT scores into discrete scores on the basis of the
  ## difficulty/threshold parameters. Should probably convert into "most
  ## probable" as I'm using the GRM and not GPCM as the underlying
  ## psychometric model, but this should be fine for the time being.
  ### - mapSco = the IRT scores to be converted
  ### - bs     = data.frame containing IRT intercepts for the conversion.
  ###            Should be an array that is conformable to the number of
  ###            elements in mapSco (usually a DF with the same number of rows
  ###            as there are elements in mapSco)
  predGen <- function(mapSco, bs){
    out <- rep(NA, dim(bs)[1])
    for(i in 1:dim(bs)[1]){
      pred <- 0
      for(j in 1:dim(bs)[2]){
        if(mapSco > bs[i, j] && !is.na(bs[i, j])){
          pred <- pred + 1
        # }else if(is.na(bs[i, j]) && !is.na(bs[i, (j - 1)])){
        #   pred <- pred + 1
        }else{
          break
        }
      }
      out[i] <- pred
    }
    out
  }
  
  ## Deprecated. Was used for rendering an empty chart with a message when
  ## some patient data were missing. Those exceptions are handled differently
  ## now that I've written code for estimating CMG.
  ### axText  = text to display on x-axis
  ### message = text to display in center of chart
  nullGoal <- function(axText, message){
    nullX <- list(range = c(0, 50),
                title = 'Date',
                zeroline = F
    )
    nullY <- list(title = axText,
                range = c(-4, 4),
                zeroline = F
    )

    nullDat <- data.frame(x = 25,
                          y = 0
    )

    output$patFIM <- renderPlotly({
      plot_ly(data = nullDat,
              x = ~x,
              y = ~y,
              type = 'scatter',
              mode = 'text',
              text = message,
              textfont = list(color = '#000000', size = 16)
      ) %>%
        layout(
          xaxis = nullX,
          yaxis = nullY,
          hoverlabel = list(font = list(size = 16))
        )
    })

    output$patGoals <- renderUI({
      div(style = 'border-radius: .28571429rem;',
        plotlyOutput('patFIM', height = '700px')
      )
    })
  }
  
  ## Deprecated; was used in demo version of dashboard before we had the FIM
  ## goals table.
  ### - x = a current FIM score
  goalGen <- function(x){
    rand1 <- runif(1)
    rand2 <- runif(1)
    if(!is.na(x)){
      if(x %in% 0:2){
        out <- 3
      }else if(x == 3 && rand1 < .25){
        out <- x + 1
      }else if(x == 3 && rand1 < .80){
        out <- x + 2
      }else if(x == 3 && rand1 >= .25 && rand1 <= .80){
        out <- x
      }else if(x == 4 && rand2 < .80){
        out <- x + 1
      }else if (x == 4 && rand2 < .20){
        out <- x - 1
      }else if(x == 4 && rand2 <= .80 && rand2 >= .20){
        out <- x
      }else{
        out <- 5
      }
    }else{
      out <- 4
    }
    out
  }
  
  ## A function for drawing the TRC when a patient is selected. Writing two
  ## separate and nearly identical functions for creating that plot was
  ## necessary due to some peculiarities with reactive values in R; old values
  ## appear to not be overwritten by new ones when the same function is rerun
  ## with new values. I don't think it's a scoping issue, but it's difficult to
  ## ascertain what the problem is. In any case, this solution works well.
  ## See the initTC_sc function for markup; this is essentailly a less complex
  ## version of that function.
  linePlotSC <- function(){
    if(!is.null(isolate(rv$scSco))){
      rv$toPlot <- isolate(as.data.frame(rv$scSco[[2]]))
      rv$toPlot$time <- rv$los - as.numeric(
                                   Sys.Date() -
                                   as.Date(rv$toPlot$assessmentDate)
                                 )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      
      if(is.null(isolate(gv$scgroup))){
        gv$scgroup <- isolate(rv$scgroup)
      }
      
      if(length(isolate(rv$scPred)) > 0){
        rv$scPred <- scPreds$yhat6[intersect(
                                     intersect(
                                       which(scPreds$scgroup == gv$scgroup),
                                       which(scPreds$msg == rv$msg)
                                     ),
                                     intersect(
                                       which(scPreds$cmg == rv$cmg),
                                       which(scPreds$longstay == gv$losgroup)
                                     )
                                   )
        ]
        isolate(rv$scPred <- rv$scPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        rv$scPred <- NA
      }
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = rv$admit,
                              to = (rv$admit + length(rv$scPred)) - 1,
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$scPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }

      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                             ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - SC Scores',
                     range = c(minScoSC_all, maxScoSC_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }else{
      rv$toPlot <- data.frame(assessmentDate = isolate(rv$admit), sc = NA,
                              bal = NA, uef = NA, swl = NA, fim = NA,
                              scSE = NA, balSE = NA, uefSE = NA, swlSE = NA,
                              fimSE = NA, time = 0
      )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(is.null(isolate(gv$scgroup))){
        gv$scgroup <- isolate(rv$scgroup)
        isolate(rv$scPred <- rv$scPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        if(!is.na(isolate(rv$cmg))){
          rv$scPred <- scPreds$yhat6[intersect(
                                       intersect(
                                         which(scPreds$scgroup == gv$scgroup),
                                         which(scPreds$msg == rv$msg)
                                       ),
                                       intersect(which(scPreds$cmg == rv$cmg),
                                                 which(
                                                   scPreds$longstay ==
                                                   gv$losgroup
                                                 )
                                       )
                                     )
          ]
        }else{
          rv$scPred <- NA
        }
      }
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = rv$admit,
                              to = (rv$admit + length(rv$scPred)) - 1,
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$scPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }
      
      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01')
                     ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - SC Scores',
                     range = c(minScoSC_all, maxScoSC_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }
    
    goalData <- fimSCGoals[fimSCGoals$FIN == isolate(rv$fin), 2:8]

    if(dim(goalData)[1] == 0){
      goalData <- data.frame(assessmentDate = NA, eating = NA, grooming = NA,
                             bathing = NA, dressingUpper = NA,
                             dressingLower = NA, toileting = NA
      )
    }
    
    if(is.null(rv$newGoalsSC)){
      goalDataRecode <- cbind(goalData, goalData - 1)
      colnames(goalDataRecode) <- c(colnames(goalData),
                                    paste0(colnames(goalData), 'R')
      )
      goalDataRecode$groomingR <- car::recode(
                                    goalDataRecode$groomingR,
                                    "0=0;1=0;2=0;3=1;4=2;5=3;6=4;NA=NA;"
      )
      goalDataRecode$bathingR <- car::recode(
                                   goalDataRecode$bathingR,
                                   "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA;"
      )
      goalDataRecode$dressingLowerR <- car::recode(
                                         goalDataRecode$dressingLowerR,
                                         "0=0;1=0;2=1;3=2;4=3;5=4;6=5;NA=NA;"
      )
      goalDataRecode$toiletingR <- car::recode(
                                     goalDataRecode$toiletingR,
                                     "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA;"
      )
      goalDataRecode <- goalDataRecode[, c(2:7, 9:14, 1)]
    }else{
      newGoalRow <- data.frame(assessmentDate = Sys.Date(),
                               eating = isolate(gv$eat),
                               grooming = isolate(gv$groom),
                               bathing = isolate(gv$bath),
                               dressingUpper = isolate(gv$ubDress),
                               dressingLower = isolate(gv$lbDress),
                               toileting = isolate(gv$toilet)
      )
      goalDataRecode <- rbind(goalData, newGoalRow)
      goalDataRecode <- cbind(goalDataRecode, goalDataRecode - 1)
      colnames(goalDataRecode) <- c(colnames(goalData),
                                    paste0(colnames(goalData), 'R')
      )
      goalDataRecode$groomingR <- car::recode(
                                    goalDataRecode$groomingR,
                                    "0=0;1=0;2=0;3=1;4=2;5=3;6=4;NA=NA;"
      )
      goalDataRecode$bathingR <- car::recode(
                                   goalDataRecode$bathingR,
                                   "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA;"
      )
      goalDataRecode$dressingLowerR <- car::recode(
                                         goalDataRecode$dressingLowerR,
                                         "0=0;1=0;2=1;3=2;4=3;5=4;6=5;NA=NA;"
      )
      goalDataRecode$toiletingR <- car::recode(
                                     goalDataRecode$toiletingR,
                                     "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA;"
      )
      goalDataRecode <- goalDataRecode[, c(2:7, 9:14, 1)]
    }
    
    if(nrow(goalDataRecode) > 1){
      goalDataRecode[, 1:12] <- apply(goalDataRecode[, 1:12], 2, repeat.before)
      deleteInd <- which(apply(goalDataRecode[, 1:12], 1,
                               function(x) all(is.na(x))
                         ) == T
      )
      if(length(deleteInd) > 0){
        goalDataRecode <- goalDataRecode[-deleteInd, ]
      }
    }
    
    if(isolate(gv$scgroup) == 1 && any(!is.na(goalDataRecode))){
      rv$fgLineDat <- cbind(matrix(rep(NA, 35 * nrow(goalDataRecode)),
                                   nrow = nrow(goalDataRecode)
                            ),
                            goalDataRecode[, 7:12]
      )
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(scModSiBal,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = siBalMeans, cov = scLTCovSiBal
                       )
                     )$F1
      )
    }else if(isolate(gv$scgroup) == 2 && any(!is.na(goalDataRecode))){
      rv$fgLineDat <- cbind(matrix(rep(NA, 41 * nrow(goalDataRecode)),
                                   nrow = nrow(goalDataRecode)
                            ),
                            goalDataRecode[, 7:12]
      )
      colnames(rv$fgLineDat)[1:41] <- stBalPar$itemName[1:41]
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(scModStBal,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = stBalMeans, cov = scLTCovStBal
                       )
                     )$F1
      )
    }else if(isolate(gv$scgroup) == 3 && any(!is.na(goalDataRecode))){
      rv$fgLineDat <- cbind(matrix(rep(NA, 40 * nrow(goalDataRecode)),
                                   nrow = nrow(goalDataRecode)
                            ),
                            goalDataRecode[, 7:12]
      )
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(scModWaBal,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = waBalMeans, cov = scLTCovWaBal
                       )
                     )$F1
      )
    }else if(all(is.na(goalDataRecode))){
      rv$fgLineDat <- NA
      rv$fgLine <- NA
    }

    scPredFull <- isolate(rv$scPredAllG)
    if(nrow(scPredFull) > 0){
      scPredFull <- scPredFull[intersect(
                                 which(scPredFull$longstay == gv$losgroup),
                                 which(scPredFull$scgroup == gv$scgroup)
      ), ]
      if(nrow(scPredFull) > 0){
        scPredFull$assessmentDate <- seq.Date(from = rv$admit,
                                              to = rv$admit + 50,
                                              by = 1
        )
      }else{
        scPredFull$assessmentDate <- NA
      }
    }else{
      scPredFull <- data.frame(time = NA, msg = NA, cmg = NA, scgroup = NA,
                               longstay = NA, yhat6 = NA, assessmentDate = NA
      )
    }
    
    rv$xAx2 <- isolate(rv$xAx)
    if(!is.na(isolate(rv$admit))){
      if(any(!is.na(isolate(rv$toPlot)))){
        rv$xAx2$range <- c(rv$admit - 1,
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(scPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        isolate(rv$xAx2$range <- c(rv$admit - 1, rv$admit + 50))
      }
    }else{
      if(all(!is.na(rv$toPlot))){
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(scPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           as.Date(Sys.Date(),
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ) + 50
        )
      }
    }

    rv$yAx2 <- list(title = 'AQ - SC Scores',
                    range = c(minScoSC_all, maxScoSC_all),
                    tickfont = list(size = 24),
                    titlefont = list(size = 24)
    )
    
    if(!is.na(isolate(rv$cmg)) && length(grep('Peds', isolate(rv$ms))) == 0){
      if(any(!is.na(isolate(rv$predPlot)))){
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$predPlot$assessmentDate[1],
                               to = rv$predPlot$assessmentDate[1] + 50,
                               by = 'day'
                             ),
                             Prediction = scPredFull$yhat6
        )
        if(any(!is.na(isolate(rv$fgLine)))){
          fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                                fgLine = isolate(rv$fgLine)
          )
          rv$predPlotFull <- merge(rv$predPlotFull,
                                   fgMerge,
                                   by = 'assessmentDate',
                                   all.x = T
          )
          rv$predPlotFull$fgLine <- repeat.before(rv$predPlotFull$fgLine)
        }else{
          rv$predPlotFull$fgLine <- NA
        }
      }else{
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$xAx2$range[1] + 1,
                               to = rv$xAx2$range[2],
                               by = 'day'
                             ),
                             Prediction = scPredFull$yhat6
        )
        if(any(!is.na(rv$fgLine))){
          fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                                fgLine = isolate(rv$fgLine)
          )
          rv$predPlotFull <- merge(rv$predPlotFull,
                                   fgMerge,
                                   by = 'assessmentDate',
                                   all.x = T
          )
          rv$predPlotFull$fgLine <- repeat.before(rv$predPlotFull$fgLine)
        }else{
          rv$predPlotFull$fgLine <- NA
        }
      }
      isolate(
      if(isolate(gv$losgroup) %in% c(1, 2)){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 18)
        ] <- NA
      }else if(isolate(gv$losgroup) == 3){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 23)
        ] <- NA
      }else if(isolate(gv$losgroup) == 4){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 30)
        ] <- NA
      }else if(isolate(gv$losgroup) == 5){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 36)
        ] <- NA
      }
      )
    }else{
      rv$predPlotFull <- data.frame(
                           assessmentDate = seq.Date(
                             from = rv$xAx2$range[1] + 1,
                             to = rv$xAx2$range[2],
                             by = 'day'
                           ),
                           Prediction = NA
      )
      if(any(!is.na(isolate(rv$fgLine)))){
        fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                              fgLine = isolate(rv$fgLine)
        )
        rv$predPlotFull <- merge(rv$predPlotFull,
                                 fgMerge,
                                 by = 'assessmentDate',
                                 all.x = T
        )
      }else{
        rv$predPlotFull$fgLine <- NA
      }
    }
    
    if(!is.null(rv$scSco[[1]])){
      aqChange <- data.frame(
                    assessmentDate = isolate(rv$toPlot$assessmentDate),
                    scChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    balChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    uefChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    swlChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1))
      )
      patFIMSC <- isolate(rv$fimSCO[rv$fimSCO$FIN == rv$fin, ])
      if(nrow(patFIMSC) > 1){
        patFIMSC$saveDate <- c(0, rep(NA, nrow(patFIMSC) - 1))
        for(i in 2:nrow(patFIMSC)){
          patFIMSC$saveDate[i] <- ifelse(all(patFIMSC[i, 3:8] ==
                                             patFIMSC[i - 1, 3:8],
                                             na.rm = T
                                         ),
                                         0, 1
          )
        }
      }else if(nrow(patFIMSC) == 1){
        patFIMSC$saveDate <- 0
      }else if(nrow(patFIMSC) < 1){
        patFIMSC[1,] <- NA
        patFIMSC$MRN <- isolate(rv$row$MRN)
        patFIMSC$FIN <- isolate(rv$row$FIN)
      }
      if(nrow(rv$toPlot) > 1){
        aqImpFwd <- as.data.frame(apply(rv$toPlot[, 2:5], 2, repeat.before))
      }else{
        aqImpFwd <- isolate(rv$toPlot[, 2:5])
      }
      if(nrow(aqImpFwd) > 1){
        for(i in 2:nrow(aqImpFwd)){
          if(any(!is.na(aqImpFwd$sc))){
            aqChange$scChange[i] <- ifelse(!(aqImpFwd$sc[i] %in%
                                             aqImpFwd$sc[i - 1]
                                           ),
                                           1, 0
            )
          }else{
            aqChange$scChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$bal))){
            aqChange$balChange[i] <- ifelse(!(aqImpFwd$bal[i] %in%
                                              aqImpFwd$bal[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$balChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$uef))){
            aqChange$uefChange[i] <- ifelse(!(aqImpFwd$uef[i] %in%
                                              aqImpFwd$uef[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$uefChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$swl))){
            aqChange$swlChange[i] <- ifelse(!(aqImpFwd$swl[i] %in%
                                              aqImpFwd$swl[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$swlChange[i] <- 0
          }
        }
        if(any(patFIMSC$saveDate != 0)){
          aqChange <- merge(aqChange, patFIMSC[, c(9, 11)],
                            by = 'assessmentDate',
                            all.x = T
          )
          aqChange$saveDate[is.na(aqChange$saveDate)] <- 0
        }else{
          aqChange$saveDate <- 0
        }
        if(any(is.na(aqChange))){
          aqChange[is.na(aqChange)] <- 0
        }
        for(i in 1:nrow(aqChange)){
          aqChange$marker[i] <- ifelse(aqChange[i, 2] == 1 &&
                                       sum(aqChange[i, 3:5]) > 0 &&
                                       aqChange[i, 6] == 0,
                                       'diamond', 'circle'
          )
        }
        rv$toPlot$marker <- aqChange$marker
      }else{
        isolate(rv$toPlot$marker <- 'circle')
      }
    }
    
    if(!('marker' %in% colnames(rv$toPlot))){
      rv$toPlot$marker <- 'circle'
    }

    output$patTC <- renderPlotly({
      plot_ly(data = rv$toPlot,
              mode = 'lines+markers',
              type = 'scatter',
              x = ~assessmentDate,
              y = ~sc,
              connectgaps = T,
              line = list(color = rv$pal[1], width = 3, dash = 'solid'),
              text = ~paste('Day ',
                            assessmentDate,
                            ': ',
                            round(sc, 2),
                            sep = ''
              ),
              name = 'AQ - Self Care',
              hoverinfo = 'text',
              marker = list(symbol = ~marker,
                            size = 8,
                            opacity = 1,
                            color = isolate(rv$pal)[1]
              ),
              showlegend = T
      ) %>%
      add_trace(data = rv$toPlot,
                x = ~assessmentDate,
                y = ~bal,
                mode = 'lines+markers',
                connectgaps = T,
                line = list(color = rv$pal[2], width = 2, dash = 'solid'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(bal, 2),
                              sep = ''
                ),
                name = 'AQ - Balance',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[2]
                ),
                showlegend = T
      ) %>%
      add_trace(data = rv$toPlot,
                x = ~assessmentDate,
                y = ~uef,
                connectgaps = T,
                mode = 'lines+markers',
                line = list(color = rv$pal[3], width = 2, dash = 'solid'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(uef, 2),
                              sep = ''
                ),
                name = 'AQ - UE Function',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[3]
                ),
                showlegend = T
      ) %>%
      add_trace(data = rv$toPlot,
                x = ~assessmentDate,
                y = ~swl,
                connectgaps = T,
                mode = 'lines+markers',
                line = list(color = rv$pal[4], width = 2, dash = 'solid'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(swl, 2),
                              sep = ''
                ),
                name = 'AQ - Swallowing',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[4]
                ),
                showlegend = T
      ) %>%
      add_trace(data = rv$predPlotFull,
                x = ~assessmentDate,
                y = ~Prediction,
                mode = 'lines+markers',
                connectgaps = T,
                line = list(color = rv$pal[5], dash = 'dash'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(Prediction, 2),
                              sep = ''
                ),
                marker = list(symbol = 'line-ns',
                              color = rv$pal[5]
                ),
                hoverinfo = 'text',
                name = 'AQ - SC Prediction',
                showlegend = T
      ) %>%
      add_trace(data = rv$predPlotFull,
                x = ~assessmentDate,
                y = ~fgLine,
                name = 'Goal → AQ',
                mode = 'lines+markers',
                line = list(color = rv$pal[1], dash = 'dash'),
                text = ~paste('Goal → AQ: ',
                              round(fgLine, 2)
                ),
                marker = list(symbol = 'line-ns'),
                hoverinfo = 'text',
                showlegend = T
      ) %>%
      layout(
        xaxis = rv$xAx2,
        yaxis = rv$yAx2,
        legend = list(orientation = 'h',
                      xanchor = 'center',
                      x = .5, y = 1.2,
                      font = list(size = 24)
        ),
        hoverlabel = list(font = list(size = 24)),
        margin = list(b = 100)
      )
    })
    
    renderInit(tail(goalDataRecode, 1))

  }
  
  ## See above
  linePlotMob <- function(){
    if(!is.null(isolate(rv$mobSco))){
      rv$toPlot <- isolate(as.data.frame(rv$mobSco[[2]]))
      rv$toPlot$time <- rv$los -
                        as.numeric(
                          Sys.Date() - as.Date(rv$toPlot$assessmentDate)
                        )
      
      if(is.null(isolate(gv$mobgroup))){
        gv$mobgroup <- isolate(rv$mobgroup)
      }
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(length(isolate(rv$mobPred)) > 0){
        rv$mobPred <- mobPreds$yhat6[intersect(
                                       intersect(
                                         which(
                                           mobPreds$mobgroup == gv$mobgroup
                                         ),
                                         which(mobPreds$msg == rv$msg)
                                       ),
                                       intersect(which(mobPreds$cmg == rv$cmg),
                                                 which(
                                                   mobPreds$longstay ==
                                                   gv$losgroup
                                                 )
                                       )
                                     )
        ]
        isolate(rv$mobPred <- rv$mobPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        rv$mobPred <- NA
      }
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = rv$admit,
                              to = (rv$admit + length(rv$mobPred)) - 1,
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$mobPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }

      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'maroon', 'gray')]

      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                             ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Mob Scores',
                     range = c(minScoMob_all, maxScoMob_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }else{
      rv$toPlot <- data.frame(assessmentDate = rv$admit, mob = NA, bal = NA,
                              wc = NA, xfer = NA, cbp = NA, scSE = NA,
                              balSE = NA, wcSE = NA, xferSE = NA, cbpSE = NA,
                              time = 0
      )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(is.null(isolate(gv$mobgroup))){
        gv$mobgroup <- isolate(rv$mobgroup)
        isolate(rv$mobPred <- rv$mobPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        if(!is.na(isolate(rv$cmg))){
          rv$mobPred <- mobPreds$yhat6[intersect(
                                         intersect(
                                           which(mobPreds$mobgroup ==
                                                 gv$mobgroup
                                           ),
                                           which(mobPreds$msg == rv$msg)
                                         ),
                                         intersect(
                                           which(mobPreds$cmg == rv$cmg),
                                           which(mobPreds$longstay ==
                                                 gv$losgroup
                                           )
                                         )
                                       )
          ]
        }else{
          rv$mobPred <- NA
        }
      }
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = rv$admit,
                              to = (rv$admit + length(rv$mobPred)) - 1,
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$mobPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }
      
      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                             ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Mob Scores',
                     range = c(minScoMob_all, maxScoMob_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      
      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'maroon', 'gray')]
    }
    
    group <- isolate(gv$mobgroup)
    
    balwlk <- ifelse(group %in% c(NA, 1),
                     'AQ - Balance', 'AQ - Balance/Walking'
    )
    
    goalData <- fimMobGoals[fimMobGoals$FIN == isolate(rv$fin), 2:8]
    
    if(dim(goalData)[1] == 0){
      goalData <- data.frame(assessmentDate = NA, bedChairTransfer = NA,
                             tubShowerTransfer = NA, toiletTransfer = NA,
                             locomotionWalk = NA, locomotionWheelchair = NA,
                             locomotionStairs = NA
      )
    }
    
    goalData[, 2:7] <- apply(goalData[, 2:7], 2, as.numeric)
    
    goalData[goalData == 0] <- NA
    
    if(is.null(isolate(rv$newGoalsMob))){
      goalDataRecode <- cbind(goalData, goalData - 1)
      colnames(goalDataRecode) <- c(colnames(goalData),
                                    paste0(
                                      colnames(goalData), 'R'
                                    )
      )
      goalDataRecode$tubShowerTransferR <- car::recode(
                                             goalDataRecode$tubShowerTransferR,
                                             "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA"
      )
      goalDataRecode <- goalDataRecode[, c(2:7, 9:14, 1)]
    }else{
      newGoalRow <- data.frame(assessmentDate = Sys.Date(),
                               bedChairTransfer = isolate(gv$bcTrans),
                               tubShowerTransfer = isolate(gv$tsTrans),
                               toiletTransfer = isolate(gv$tTrans),
                               locomotionWalk = isolate(gv$locWalk),
                               locomotionWheelchair = isolate(gv$locWheel),
                               locomotionStairs = isolate(gv$locStairs)
      )
      goalDataRecode <- rbind(goalData, newGoalRow) 
      goalDataRecode <- cbind(goalDataRecode, goalDataRecode - 1)
      colnames(goalDataRecode) <- c(colnames(goalData),
                                    paste0(
                                      colnames(goalData), 'R'
                                    )
      )
      goalDataRecode$tubShowerTransferR <- car::recode(
                                             goalDataRecode$tubShowerTransferR,
                                             "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA"
      )
      goalDataRecode <- goalDataRecode[, c(2:7, 9:14, 1)]
    }

    if(nrow(goalDataRecode) > 1){
      goalDataRecode[, 1:12] <- apply(goalDataRecode[, 1:12], 2, repeat.before)
      deleteInd <- which(apply(goalDataRecode[, 1:12], 1,
                               function(x) all(is.na(x))
                         ) == T
      )
      if(length(deleteInd) > 0){
        goalDataRecode <- goalDataRecode[-deleteInd, ]
      }
    }

    if(isolate(gv$mobgroup) == 1 && any(!is.na(goalDataRecode[, c(7:9, 11)]))){
      rv$fgLineDat <- cbind(matrix(rep(NA, 11 * nrow(goalDataRecode)),
                                   nrow = nrow(goalDataRecode)
                            ),
                            goalDataRecode[, c(7:9, 11)]
      )
      rv$fgLine <- as.numeric(as.data.frame(
                                fscores(mobModWheel,
                                        response.pattern = rv$fgLineDat,
                                        method = 'MAP', theta_lim = c(-6, 6),
                                        mean = wheelMeans, cov = mobLTCovWheel
                                )
                              )$F1
      )
    }else if(isolate(gv$mobgroup) == 2 && any(!is.na(goalDataRecode[, 7:12]))){
      rv$fgLineDat <- cbind(matrix(rep(NA, 17 * nrow(goalDataRecode)),
                                   nrow = nrow(goalDataRecode)
                            ),
                            goalDataRecode[, 7:12]
      )
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(mobModBoth,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = bothMeans, cov = mobLTCovBoth
                       )
                     )$F1
      )
    }else if(isolate(gv$mobgroup) == 3 && any(!is.na(goalDataRecode[, 7:12]))){
      rv$fgLineDat <- cbind(matrix(rep(NA, 15 * nrow(goalDataRecode)),
                                   nrow = nrow(goalDataRecode)
                            ),
                            goalDataRecode[, 7:12]
      )
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(mobModWalk,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP',
                               theta_lim = c(-6, 6),
                               mean = walkMeans, cov = mobLTCovWalk
                       )
                     )$F1
      )
    }else if(all(is.na(isolate(rv$newGoalsMob)))){
      rv$fgLineDat <- NA
      rv$fgLine <- NA
    }

    mobPredFull <- isolate(rv$mobPredAllG)
    if(nrow(mobPredFull) > 0){
      mobPredFull <- mobPredFull[intersect(
                                   which(mobPredFull$longstay == gv$losgroup),
                                   which(mobPredFull$mobgroup == gv$mobgroup)
                                 )
      , ]
      if(nrow(mobPredFull) > 0){
        mobPredFull$assessmentDate <- seq.Date(from = rv$admit,
                                               to = rv$admit + 50,
                                               by = 1
        )
      }else{
        mobPredFull$assessmentDate <- NA
      }
    }else{
      mobPredFull <- data.frame(time = NA, msg = NA, cmg = NA, mobgroup = NA,
                                longstay = NA, yhat6 = NA, assessmentDate = NA
      )
    }

    rv$xAx2 <- isolate(rv$xAx)
    if(!is.na(isolate(rv$admit))){
      if(any(!is.na(isolate(rv$toPlot)))){
        rv$xAx2$range <- c(rv$admit - 1,
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(mobPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        isolate(rv$xAx2$range <- c(rv$admit - 1, rv$admit + 50))
      }
    }else{
      if(all(!is.na(rv$toPlot))){
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(mobPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           as.Date(Sys.Date(),
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01') + 50
                           )
      }
    }

    rv$yAx2 <- list(title = 'AQ - Mob Scores',
                    range = c(minScoMob_all, maxScoMob_all),
                    tickfont = list(size = 24),
                    titlefont = list(size = 24)
    )
    
    isolate(
    if(!is.na(isolate(rv$cmg)) && length(grep('Peds', isolate(rv$ms))) == 0){
      if(any(!is.na(isolate(rv$predPlot)))){
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$predPlot$assessmentDate[1],
                               to = rv$predPlot$assessmentDate[1] + 50,
                               by = 'day'
                             ),
                             Prediction = mobPredFull$yhat6
        )
        if(any(!is.na(isolate(rv$fgLine)))){
          fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                                fgLine = isolate(rv$fgLine)
          )
          rv$predPlotFull <- merge(rv$predPlotFull,
                                   fgMerge,
                                   by = 'assessmentDate',
                                   all.x = T
          )
          rv$predPlotFull$fgLine <- repeat.before(rv$predPlotFull$fgLine)
        }else{
          rv$predPlotFull$fgLine <- NA
        }
      }else{
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$xAx2$range[1] + 1,
                               to = rv$xAx2$range[2],
                               by = 'day'
                             ),
                             Prediction = mobPredFull$yhat6
        )
        if(any(!is.na(isolate(rv$fgLine)))){
          fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                                fgLine = isolate(rv$fgLine)
          )
          rv$predPlotFull <- merge(rv$predPlotFull,
                                   fgMerge,
                                   by = 'assessmentDate',
                                   all.x = T
          )
          rv$predPlotFull$fgLine <- repeat.before(rv$predPlotFull$fgLine)
        }else{
          rv$predPlotFull$fgLine <- NA
        }
      }
      isolate(
      if(isolate(gv$losgroup) %in% c(1, 2)){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 18)
        ] <- NA
      }else if(isolate(gv$losgroup) == 3){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 23)
        ] <- NA
      }else if(isolate(gv$losgroup) == 4){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 30)
        ] <- NA
      }else if(isolate(gv$losgroup) == 5){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 36)
        ] <- NA
      }
      )
    }else{
      rv$predPlotFull <- data.frame(
                           assessmentDate = seq.Date(
                             from = rv$xAx2$range[1] + 1,
                             to = rv$xAx2$range[2],
                             by = 'day'
                           ),
                           Prediction = NA
      )
      if(any(!is.na(isolate(rv$fgLine)))){
        fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                              fgLine = isolate(rv$fgLine)
        )
        rv$predPlotFull <- merge(rv$predPlotFull,
                                 fgMerge,
                                 by = 'assessmentDate',
                                 all.x = T
        )
      }else{
        rv$predPlotFull$fgLine <- NA
      }
    }
    )

    if(isolate(gv$mobgroup) != 1){
      isolate(rv$toPlot$cbp <- NA)
    }
    
    if(!is.null(rv$mobSco[[1]])){
      aqChange <- data.frame(
                    assessmentDate = isolate(rv$toPlot$assessmentDate),
                    mobChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    balChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    wcChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    xferChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    cbpChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1))
      )
      patFIMMob <- isolate(rv$fimMobO[rv$fimMobO$FIN == rv$fin, ])
      if(nrow(patFIMMob) > 1){
        patFIMMob$saveDate <- c(0, rep(NA, nrow(patFIMMob) - 1))
        for(i in 2:nrow(patFIMMob)){
          patFIMMob$saveDate[i] <- ifelse(all(patFIMMob[i, 3:8] ==
                                              patFIMMob[i - 1, 3:8],
                                              na.rm = T
                                          ),
                                          0, 1
          )
        }
      }else if(nrow(patFIMMob) == 1){
        patFIMMob$saveDate <- 0
      }else if(nrow(patFIMMob) < 1){
        patFIMMob[1,] <- NA
        patFIMMob$MRN <- isolate(rv$row$MRN)
        patFIMMob$FIN <- isolate(rv$row$FIN)
      }
      if(nrow(rv$toPlot) > 1){
        aqImpFwd <- as.data.frame(
                      apply(rv$toPlot[, c('mob', 'bal', 'wc', 'xfer', 'cbp')],
                            2, repeat.before
                      )
        )
      }else{
        aqImpFwd <- isolate(rv$toPlot[, c('mob', 'bal', 'wc', 'xfer', 'cbp')])
      }
      if(nrow(aqImpFwd) > 1){
        for(i in 2:nrow(aqImpFwd)){
          if(any(!is.na(aqImpFwd$mob))){
            aqChange$mobChange[i] <- ifelse(!(aqImpFwd$mob[i] %in%
                                              aqImpFwd$mob[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$mobChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$bal))){
            aqChange$balChange[i] <- ifelse(!(aqImpFwd$bal[i] %in%
                                              aqImpFwd$bal[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$balChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$wc))){
            aqChange$wcChange[i] <- ifelse(!(aqImpFwd$wc[i] %in%
                                             aqImpFwd$wc[i - 1]
                                           ),
                                           1, 0
            )
          }else{
            aqChange$wcChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$xfer))){
            aqChange$xferChange[i] <- ifelse(!(aqImpFwd$xfer[i] %in%
                                               aqImpFwd$xfer[i - 1]
                                             ),
                                             1, 0
            )
          }else{
            aqChange$xferChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$cbp))){
            aqChange$cbpChange[i] <- ifelse(!(aqImpFwd$cbp[i] %in%
                                              aqImpFwd$cbp[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$cbpChange[i] <- 0
          }
        }
        if(any(patFIMMob$saveDate != 0)){
          aqChange <- merge(aqChange, patFIMMob[, c(9:10)],
                            by = 'assessmentDate',
                            all.x = T
          )
          aqChange$saveDate[is.na(aqChange$saveDate)] <- 0
        }else{
          aqChange$saveDate <- 0
        }
        if(any(is.na(aqChange))){
          aqChange[is.na(aqChange)] <- 0
        }
        for(i in 1:nrow(aqChange)){
          aqChange$marker[i] <- ifelse(aqChange[i, 2] == 1 &&
                                       sum(aqChange[i, 3:6]) > 0 &&
                                       aqChange[i, 7] == 0,
                                       'diamond', 'circle'
          )
        }
        rv$toPlot$marker <- aqChange$marker
      }else{
        isolate(rv$toPlot$marker <- 'circle')
      }
    }
    
    if(!('marker' %in% colnames(rv$toPlot))){
      rv$toPlot$marker <- 'circle'
    }
    
    output$patTC <- renderPlotly({
      plot_ly(data = rv$toPlot,
              mode = 'lines+markers',
              type = 'scatter',
              x = ~assessmentDate,
              y = ~mob,
              connectgaps = T,
              line = list(color = rv$pal[1], width = 3, dash = 'solid'),
              text = ~paste('Day ',
                            assessmentDate,
                            ': ',
                            round(mob, 2),
                            sep = ''
              ),
              name = 'AQ - Mobility',
              hoverinfo = 'text',
              marker = list(symbol = ~marker,
                            size = 8,
                            opacity = 1,
                            color = isolate(rv$pal)[1]
              ),
              showlegend = T
      ) %>%
      add_trace(data = rv$toPlot,
                x = ~assessmentDate,
                y = ~bal,
                mode = 'lines+markers',
                connectgaps = T,
                line = list(color = rv$pal[2], width = 2, dash = 'solid'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(bal, 2),
                              sep = ''
                ),
                name = balwlk,
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[2]
                ),
                showlegend = T
      ) %>%
      add_trace(data = rv$toPlot,
                x = ~assessmentDate,
                y = ~wc,
                connectgaps = T,
                mode = 'lines+markers',
                line = list(color = rv$pal[3], width = 2, dash = 'solid'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(wc, 2),
                              sep = ''
                ),
                name = 'AQ - Wheelchair',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[3]
                ),
                showlegend = T
      ) %>%
      add_trace(data = rv$toPlot,
                x = ~assessmentDate,
                y = ~xfer,
                connectgaps = T,
                mode = 'lines+markers',
                line = list(color = rv$pal[4], width = 2, dash = 'solid'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(xfer, 2),
                              sep = ''
                ),
                name = 'AQ - Bathroom Transfers',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[4]
                ),
                showlegend = T
      ) %>%
      add_trace(data = rv$toPlot,
                x = ~assessmentDate,
                y = ~cbp,
                connectgaps = T,
                mode = 'lines+markers',
                line = list(color = rv$pal[5], width = 2, dash = 'solid'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(cbp, 2),
                              sep = ''
                ),
                name = 'AQ - Changing Body Position',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[5]
                ),
                showlegend = T
      ) %>%
      add_trace(data = rv$predPlotFull,
                x = ~assessmentDate,
                y = ~Prediction,
                mode = 'lines+markers',
                connectgaps = T,
                line = list(color = rv$pal[6], dash = 'dash'),
                text = ~paste(assessmentDate,
                              ': ',
                              round(Prediction, 2),
                              sep = ''
                ),
                marker = list(symbol = 'line-ns',
                              color = rv$pal[6]
                ),
                hoverinfo = 'text',
                name = 'AQ - Mob Prediction',
                showlegend = T
      ) %>%
      add_trace(data = rv$predPlotFull,
                y = ~fgLine,
                x = ~assessmentDate,
                name = 'Goal → AQ',
                mode = 'lines+markers',
                line = list(color = rv$pal[1], dash = 'dash'),
                text = ~paste('Goal → AQ: ', 
                              round(fgLine, 2)
                ),
                marker = list(symbol = 'line-ns'),
                hoverinfo = 'text',
                showlegend = T
      ) %>%
      layout(
        xaxis = rv$xAx2,
        yaxis = rv$yAx2,
        legend = list(orientation = 'h',
                      xanchor = 'center',
                      x = .5, y = 1.2,
                      font = list(size = 24)
        ),
        hoverlabel = list(font = list(size = 24)),
        margin = list(b = 100)
      )
    })
    
    renderInit(tail(goalDataRecode, 1))
  }
  
  ## See above
  linePlotCog <- function(){
    if(!is.null(isolate(rv$cogSco))){
      rv$toPlot <- isolate(as.data.frame(rv$cogSco[[2]]))
      rv$toPlot$time <- rv$los -
                        as.numeric(Sys.Date() -
                                   as.Date(rv$toPlot$assessmentDate)
                        )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      
      if(is.null(isolate(gv$coggroup))){
        gv$coggroup <- isolate(rv$coggroup)
      }
      
      if(length(isolate(rv$cogPred)) > 0){
        rv$cogPred <- cogPreds$yhat6[intersect(
                                       intersect(
                                         which(
                                           cogPreds$coggroup ==
                                           gv$coggroup
                                         ),
                                         which(cogPreds$msg == rv$msg)
                                       ),
                                       intersect(
                                         which(cogPreds$cmg == rv$cmg),
                                         which(
                                           cogPreds$longstay ==
                                           gv$losgroup
                                         )
                                       )
                                     )
        ]
        isolate(rv$cogPred <- rv$cogPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        rv$cogPred <- NA
      }

      isolate(
      if(!is.na(isolate(gv$coggroup))){
        if(!('spe' %in% colnames(rv$toPlot))){
          rv$toPlot$spe <- NA
        }
        if(!('mem' %in% colnames(rv$toPlot))){
          rv$toPlot$mem <- NA
        }
        if(!('agi' %in% colnames(rv$toPlot))){
          rv$toPlot$agi <- NA
        }
        if(!('com' %in% colnames(rv$toPlot))){
          rv$toPlot$com <- NA
        }
        if(!('wcom' %in% colnames(rv$toPlot))){
          rv$toPlot$wcom <- NA
        }
        if(!('comp' %in% colnames(rv$toPlot))){
          rv$toPlot$comp <- NA
        }
      }
      )
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = rv$admit,
                              to = (rv$admit + length(rv$cogPred)) - 1,
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$cogPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }

      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                             ),
                  title = 'Date',
                  tickfont = list(size = 24),
                  titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Cog Scores',
                     range = c(minScoCog_all, maxScoCog_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }else{
      rv$toPlot <- data.frame(assessmentDate = rv$admit, cog = NA, com = NA,
                              spe = NA, wcom = NA, mem = NA, comp = NA,
                              agi = NA, cogSE = NA, comSE = NA, speSE = NA,
                              wcomSE = NA, memSE = NA, compSE = NA, agiSE = NA,
                              time = 0
      )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(is.null(isolate(gv$coggroup))){
        gv$coggroup <- isolate(rv$coggroup)
        isolate(rv$cogPred <- rv$cogPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        if(!is.na(isolate(rv$cmg))){
          rv$cogPred <- cogPreds$yhat6[intersect(
                                         intersect(
                                           which(
                                             cogPreds$cogroup == gv$coggroup),
                                             which(cogPreds$msg == rv$msg)
                                           ),
                                           intersect(
                                             which(cogPreds$cmg == rv$cmg),
                                             which(
                                               cogPreds$longstay == gv$losgroup
                                             )
                                           )
                                       )
          ]
        }else{
          rv$cogPred <- NA
        }
      }
      
      isolate(
      if(!is.na(gv$coggroup)){
        if(isolate(gv$coggroup) == 1){
          rv$toPlot$spe <- NA
          rv$toPlot$mem <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 2){
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 3){
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
        }else if(isolate(gv$coggroup) == 4){
          rv$toPlot$spe <- NA
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 5){
          rv$toPlot$mem <- NA
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }
      }
      )
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = rv$admit,
                              to = (rv$admit + length(rv$cogPred)) - 1,
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$cogPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }
      
      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                     ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Cog Scores',
                     range = c(minScoCog_all, maxScoCog_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }
    
    goalData <- fimCogGoals[fimCogGoals$FIN == isolate(rv$fin), 2:7]
    
    if(dim(goalData)[1] == 0){
      goalData <- data.frame(assessmentDate = NA, comprehension = NA,
                             expression = NA, socialInteraction = NA,
                             problemSolving = NA, memory = NA
      )
    }
    
    if(is.null(isolate(rv$newGoalsCog))){
      goalDataRecode <- goalData
      goalDataRecode[, 2:6] <- goalDataRecode[, 2:6] - 1
      goalDataRecode <- goalDataRecode[, c(2:6, 1)]
    }else{
      newGoalRow <- data.frame(assessmentDate = Sys.Date(),
                                comprehension = isolate(gv$comp) - 1,
                                expression = isolate(gv$exp) - 1,
                                socialInteraction = isolate(gv$si) - 1,
                                problemSolving = isolate(gv$ps) - 1,
                                memory = isolate(gv$mem) - 1
      )
      goalDataRecode <- goalData
      goalDataRecode[, 2:6] <- goalDataRecode[, 2:6] - 1
      goalDataRecode <- rbind(goalDataRecode, newGoalRow)
      goalDataRecode <- goalDataRecode[, c(2:6, 1)]
    }

    if(nrow(goalDataRecode) > 1){
      goalDataRecode[, 1:5] <- apply(goalDataRecode[, 1:5], 2, repeat.before)
      deleteInd <- which(apply(goalDataRecode[, 1:5], 1,
                               function(x) all(is.na(x))
                         ) == T
      )
      if(length(deleteInd) > 0){
        goalDataRecode <- goalDataRecode[-deleteInd, ]
      }
    }
    
    if(!is.na(isolate(gv$coggroup))){
      if(isolate(gv$coggroup) == 1 && any(!is.na(goalDataRecode))){
        rv$fgLineDat <- cbind(matrix(rep(NA, 16 * nrow(goalDataRecode)),
                                     nrow = nrow(goalDataRecode)
                              ),
                              goalDataRecode[, 1:5]
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModAph,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = aphMeans, cov = cogLTCovAph
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 2 && any(!is.na(goalDataRecode))){
        rv$fgLineDat <- cbind(matrix(rep(NA, 13 * nrow(goalDataRecode)),
                                     nrow = nrow(goalDataRecode)
                              ),
                              goalDataRecode[, 1:5]
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModCCD,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = ccdMeans, cov = cogLTCovCCD
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 3 && any(!is.na(goalDataRecode))){
        rv$fgLineDat <- cbind(matrix(rep(NA, 15 * nrow(goalDataRecode)),
                                     nrow = nrow(goalDataRecode)
                              ),
                              goalDataRecode[, 1:5]
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModBI,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = biMeans, cov = cogLTCovBI
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 4 && any(!is.na(goalDataRecode))){
        rv$fgLineDat <- cbind(matrix(rep(NA, 11 * nrow(goalDataRecode)),
                                     nrow = nrow(goalDataRecode)
                              ),
                              goalDataRecode[, 1:5]
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModRHD,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = rhdMeans, cov = cogLTCovRHD
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 5 && any(!is.na(goalDataRecode))){
        rv$fgLineDat <- cbind(matrix(rep(NA, 4 * nrow(goalDataRecode)),
                                     nrow = nrow(goalDataRecode)
                              ),
                              goalDataRecode[, 1:5]
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModSpe,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = speMeans, cov = cogLTCovSpe
                                  )
                                )$F1
        )
      }else if(all(is.na(goalDataRecode))){
        rv$fgLineDat <- NA
        rv$fgLine <- NA
      }
    }else{
      rv$fgLineDat <- NA
      rv$fgLine <- NA
    }
    
    cogPredFull <- isolate(rv$cogPredAllG)
    if(nrow(cogPredFull) > 0){
      cogPredFull <- cogPredFull[intersect(
                                   which(cogPredFull$longstay == gv$losgroup),
                                   which(cogPredFull$coggroup == gv$coggroup)
                                 )
      , ]
      if(nrow(cogPredFull) > 0){
        cogPredFull$assessmentDate <- seq.Date(from = rv$admit,
                                               to = rv$admit + 50,
                                               by = 1
        )
      }else{
        cogPredFull$assessmentDate <- NA
      }
    }else{
      cogPredFull <- data.frame(time = NA, msg = NA, cmg = NA, coggroup = NA,
                                longstay = NA, yhat6 = NA, assessmentDate = NA
      )
    }
    
    rv$xAx2 <- isolate(rv$xAx)
    if(!is.na(isolate(rv$admit))){
      if(any(!is.na(isolate(rv$toPlot)))){
        rv$xAx2$range <- c(rv$admit - 1,
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(cogPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(isolate(rv$admit) - 1, isolate(rv$admit) + 50)
      }
    }else{
      if(all(!is.na(rv$toPlot))){
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(cogPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           as.Date(Sys.Date(),
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ) + 50
        )
      }
    }
    
    rv$yAx2 <- list(title = 'AQ - Cog Scores',
                    range = c(minScoCog_all, maxScoCog_all),
                    tickfont = list(size = 24),
                    titlefont = list(size = 24)
    )
    
    if(!is.na(isolate(rv$cmg)) && length(grep('Peds', isolate(rv$ms))) == 0){
      if(any(!is.na(isolate(rv$predPlot)))){
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$predPlot$assessmentDate[1],
                               to = rv$predPlot$assessmentDate[1] + 50,
                               by = 'day'
                             ),
                             Prediction = cogPredFull$yhat6
        )
        if(any(!is.na(isolate(rv$fgLine)))){
          fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                                fgLine = isolate(rv$fgLine)
          )
          rv$predPlotFull <- merge(rv$predPlotFull,
                                   fgMerge,
                                   by = 'assessmentDate',
                                   all.x = T
          )
          rv$predPlotFull$fgLine <- repeat.before(rv$predPlotFull$fgLine)
        }else{
          rv$predPlotFull$fgLine <- NA
        }
      }else{
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$xAx2$range[1] + 1,
                               to = rv$xAx2$range[2],
                               by = 'day'
                             ),
                             Prediction = cogPredFull$yhat6
        )
        if(any(!is.na(rv$fgLine))){
          fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                                fgLine = isolate(rv$fgLine)
          )
          rv$predPlotFull <- merge(rv$predPlotFull,
                                   fgMerge,
                                   by = 'assessmentDate',
                                   all.x = T
          )
          rv$predPlotFull$fgLine <- repeat.before(rv$predPlotFull$fgLine)
        }else{
          rv$predPlotFull$fgLine <- NA
        }
      }

      if(isolate(gv$losgroup) %in% c(1, 2)){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 18)
        ] <- NA
      }else if(isolate(gv$losgroup) == 3){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 23)
        ] <- NA
      }else if(isolate(gv$losgroup) == 4){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 30)
        ] <- NA
      }else if(isolate(gv$losgroup) == 5){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 36)
        ] <- NA
      }
    }else{
      rv$predPlotFull <- data.frame(
                           assessmentDate = seq.Date(
                             from = rv$xAx2$range[1] + 1,
                             to = rv$xAx2$range[2],
                             by = 'day'
                           ),
                           Prediction = NA
      )
      if(any(!is.na(isolate(rv$fgLine)))){
        fgMerge <- data.frame(assessmentDate = goalDataRecode$assessmentDate,
                              fgLine = isolate(rv$fgLine)
        )
        rv$predPlotFull <- merge(rv$predPlotFull,
                                 fgMerge,
                                 by = 'assessmentDate',
                                 all.x = T
        )
      }else{
        rv$predPlotFull$fgLine <- NA
      }
    }
    
    if(!is.null(rv$cogSco[[1]])){
      aqChange <- data.frame(
                    assessmentDate = isolate(rv$toPlot$assessmentDate),
                    cogChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    memChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    speChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    agiChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    comChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    wcomChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    compChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1))
      )
      patFIMCog <- isolate(rv$fimCogO[rv$fimCogO$FIN == rv$fin, ])
      if(nrow(patFIMCog) > 1){
        patFIMCog$saveDate <- c(0, rep(NA, nrow(patFIMCog) - 1))
        for(i in 2:nrow(patFIMCog)){
          patFIMCog$saveDate[i] <- ifelse(all(patFIMCog[i, 3:7] ==
                                              patFIMCog[i - 1, 3:7],
                                              na.rm = T
                                          ),
                                          0, 1
          )
        }
      }else if(nrow(patFIMCog) == 1){
        patFIMCog$saveDate <- 0
      }else if(nrow(patFIMCog) < 1){
        patFIMCog[1,] <- NA
        patFIMCog$MRN <- isolate(rv$row$MRN)
        patFIMCog$FIN <- isolate(rv$row$FIN)
      }
      if(nrow(rv$toPlot) > 1){
        aqImpFwd <- as.data.frame(
                      apply(rv$toPlot[, c('cog', 'mem', 'spe', 'agi', 'com',
                                          'wcom', 'comp'
                                        )
                            ],
                            2, repeat.before
                      )
        )
      }else{
        aqImpFwd <- isolate(rv$toPlot[, c('cog', 'mem', 'spe', 'agi', 'com',
                                          'wcom', 'comp'
                                        )
                            ]
        )
      }
      if(nrow(aqImpFwd) > 1){
        for(i in 2:nrow(aqImpFwd)){
          if(any(!is.na(aqImpFwd$cog))){
            aqChange$cogChange[i] <- ifelse(!(aqImpFwd$cog[i] %in%
                                              aqImpFwd$cog[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$cogChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$mem))){
            aqChange$memChange[i] <- ifelse(!(aqImpFwd$mem[i] %in%
                                              aqImpFwd$mem[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$memChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$spe))){
            aqChange$speChange[i] <- ifelse(!(aqImpFwd$spe[i] %in%
                                              aqImpFwd$spe[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$speChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$com))){
            aqChange$comChange[i] <- ifelse(!(aqImpFwd$com[i] %in%
                                              aqImpFwd$com[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$comChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$wcom))){
            aqChange$wcomChange[i] <- ifelse(!(aqImpFwd$wcom[i] %in%
                                               aqImpFwd$wcom[i - 1]
                                             ),
                                             1, 0
            )
          }else{
            aqChange$wcomChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$comp))){
            aqChange$compChange[i] <- ifelse(!(aqImpFwd$comp[i] %in%
                                               aqImpFwd$comp[i - 1]
                                             ),
                                             1, 0
            )
          }else{
            aqChange$compChange[i] <- 0
          }
        }
        if(any(patFIMCog$saveDate != 0)){
          aqChange <- merge(aqChange, patFIMCog[, c(8, 10)],
                            by = 'assessmentDate',
                            all.x = T
          )
          aqChange$saveDate[is.na(aqChange$saveDate)] <- 0
        }else{
          aqChange$saveDate <- 0
        }
        if(any(is.na(aqChange))){
          aqChange[is.na(aqChange)] <- 0
        }
        for(i in 1:nrow(aqChange)){
          aqChange$marker[i] <- ifelse(aqChange[i, 2] == 1 &&
                                       sum(aqChange[i, 3:8]) > 0 &&
                                       aqChange[i, 9] == 0,
                                       'diamond', 'circle'
          )
        }
        rv$toPlot$marker <- aqChange$marker
      }else{
        isolate(rv$toPlot$marker <- 'circle')
      }
    }
    
    if(!('marker' %in% colnames(rv$toPlot))){
      rv$toPlot$marker <- 'circle'
    }
    
    output$patTC <- renderPlotly({
      plot_ly(data = rv$toPlot,
              type = 'scatter',
              mode = 'lines+markers',
              x = ~assessmentDate,
              y = ~cog,
              connectgaps = T,
              line = list(color = rv$pal[1], dash = 'solid'),
              text = ~paste(assessmentDate,
                            ': ',
                            round(cog, 2),
                            sep = ''
              ),
              name = 'AQ - Cognition',
              hoverinfo = 'text',
              marker = list(symbol = ~marker,
                            size = 8,
                            color = isolate(rv$pal)[1]
              )
      ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~com,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[2],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(com, 2),
                                sep = ''
                  ),
                  name = 'AQ - Communication',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[2]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~spe,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[2], width = 2, dash = 'solid'),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(spe, 2),
                                sep = ''
                  ),
                  name = 'AQ - Speech',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[2]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~wcom,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[3], width = 2, dash = 'solid'),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(wcom, 2),
                                sep = ''
                  ),
                  name = 'AQ - Writing',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[3]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~mem,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[3], width = 2, dash = 'solid'),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(mem, 2),
                                sep = ''
                  ),
                  name = 'AQ - Memory',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[3]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~comp,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[4], width = 2, dash = 'solid'),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(comp, 2),
                                sep = ''
                  ),
                  name = 'AQ - Comprehension',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[4]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~agi,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[4], width = 2, dash = 'solid'),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(agi, 2),
                                sep = ''
                  ),
                  name = 'AQ - Agitation',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[4]
                  )
        ) %>%
        add_trace(data = rv$predPlotFull,
                  x = ~assessmentDate,
                  y = ~Prediction,
                  type = 'scatter',
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[5], dash = 'dash'),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(Prediction, 2),
                                sep = ''
                  ),
                  marker = list(symbol = 'line-ns', color = rv$pal[5]),
                  hoverinfo = 'text',
                  name = 'AQ - Cog Prediction'
        ) %>%
        add_trace(data = rv$predPlotFull,
                  y = ~fgLine,
                  x = ~assessmentDate,
                  name = 'Goal → AQ',
                  mode = 'lines+markers',
                  line = list(color = rv$pal[1], dash = 'dash'),
                  text = ~paste('Goal → AQ: ', 
                                round(fgLine, 2)
                  ),
                  marker = list(symbol = 'line-ns'),
                  hoverinfo = 'text'
        ) %>%
        layout(
          xaxis = rv$xAx2,
          yaxis = rv$yAx2,
          legend = list(orientation = 'h',
                        xanchor = 'center',
                        x = .5, y = 1.2,
                        font = list(size = 24)
          ),
          hoverlabel = list(font = list(size = 24)),
          margin = list(b = 100)
        )
    })
    
    renderInit(tail(goalDataRecode, 1))
    
  }

  ## This function is used to update the Typical Recovery Curve charts when
  ## patient options, FIM scores, or FIM Goals are edited by the user. Note:
  ## All options for this function are deprecated. I didn't realize at the
  ## time that reactive values are accessible to all R environments and
  ## don't need to be passed to functions like non-reactive values. As such,
  ## some value has to be passed to each option, even if it's nonsense. I'll
  ## clean this up eventually. Note that the _mob and _cog flavors of this
  ## function are identical except with respect to the data going into them.
  ### - toPlot    = a data.frame containing the AQ scores to be displayed
  ### - predPlot  = a data.frame containing the relevant predictive model
  ###               information for the patient
  ### - fgLine    = a data.frame or simple vector containing the FIM goals
  ###               (converted to AQ metric) for the patient
  ### - goalGroup = the patient's grouping variable; balance level for SC
  ### - losGroup  = the patient's length of stay group
  ### - xAx       = the plotly-formatted x-axis list
  ### - yAx       = the plotly-formatted y-axis list
  initTC_sc <- function(toPlot, predPlot, fgLine, goalGroup, losGroup, xAx,
                        yAx, pal
               )
  {
    ## Pull the current input values from the FIM Goals selectInputs. This
    ## effectively does nothing if they have not been modified as they default
    ## to the most recent FIM goals if left alone.
    gv$eat <- as.numeric(isolate(input$eat))
    gv$groom <- as.numeric(isolate(input$groom))
    gv$bath <- as.numeric(isolate(input$bath))
    gv$ubDress <- as.numeric(isolate(input$ubDress))
    gv$lbDress <- as.numeric(isolate(input$lbDress))
    gv$toilet <- as.numeric(isolate(input$toilet))
    
    ## Convert the goals to their appropriate formats for AQ scoring
    gv$eatR <- isolate(gv$eat) - 1
    gv$groomR <- car::recode(isolate(gv$groom) - 1,
                             "0=0;1=0;2=0;3=1;4=2;5=3;6=4;NA=NA;"
    )
    gv$bathR <- car::recode(isolate(gv$bath) - 1,
                            "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA;"
    )
    gv$ubDressR <- isolate(gv$ubDress) - 1
    gv$lbDressR <- car::recode(isolate(gv$lbDress) - 1,
                               "0=0;1=0;2=1;3=2;4=3;5=4;6=5;NA=NA;"
    )
    gv$toiletR <- car::recode(isolate(gv$toilet) - 1,
                              "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA;"
    )
    
    ## Put the converted goals into their own reactive value so that further
    ## modifications can be recorded
    rv$newGoalsSC <- data.frame(eating = isolate(gv$eatR),
                                grooming = isolate(gv$groomR),
                                bathing = isolate(gv$bathR),
                                dressingUpper = isolate(gv$ubDressR),
                                dressingLower = isolate(gv$lbDressR),
                                toileting = isolate(gv$toiletR)
    )
    
    ## Capture the input for balance level if changed. Again, this selectInput
    ## defaults to the most recent balance level designation, so it will be
    ## appropriate if unchanged.
    gv$scgroup <- as.numeric(isolate(input$balLevel))

    ## If there's any 88s around, change them to missing.
    if(dim(isolate(rv$scData))[1] > 0 &&
       any(isolate(apply(rv$scData[, 5:56], c(1, 2),
                         function(x) !is.na(x) && x < 10
                   ))
       ))
    {
      ## This was meant for controlling which domains are considered relevant
      ## to scoring. I've since deprecated the balance and UEF ones, but the
      ## swallowing switch is still active.
      if(any(c(isolate(uv$balsc_switch),
               isolate(uv$uef_switch),
               isolate(uv$swl_switch)) == 0
             )
         )
      {
        tempDat <- isolate(rv$scData)
        if(isolate(uv$balsc_switch) == 0){
          tempDat[, 5:21] <- NA
        }
        if(isolate(uv$uef_switch) == 0){
          tempDat[, 22:38] <- NA
        }
        if(isolate(uv$swl_switch) == 0){
          tempDat[, 39:50] <- NA
        }
        rv$scSco <- scoFunSCFIM(data = tempDat, group = isolate(gv$scgroup))
      }else{
        rv$scSco <- scoFunSCFIM(data = isolate(rv$scData),
                                group = isolate(gv$scgroup)
        )
      }
    }else{
      rv$scSco <- NULL
    }
    
    ## If there's cases where there are no FIM data, but still AQ-SC scores,
    ## pretend there's no data. This is mostly a bug-catch that I found while
    ## trying to break various aspects of the dashboard. Circumstances in which
    ## this would be triggered are rare, if existant at all (FIM is always 
    ## supposed to be documented first).
    if(dim(isolate(rv$scSco)[[3]])[1] == 0 && !is.null(rv$scSco)){
      rv$scSco <- NULL
    }
    
    ## If all the checks on the AQ-SC scores have been passed and it's still
    ## not NULL...
    if(!is.null(rv$scSco)){
      ## Establish the AQ-SC scores as the element to be plotted
      rv$toPlot <- as.data.frame(rv$scSco[[2]])
      ## Create a time variable ranging from 0 (admission) to current date
      rv$toPlot$time <- isolate(rv$los) -
                        as.numeric(
                          Sys.Date() - as.Date(rv$toPlot$assessmentDate)
                        )
      
      ## If the LoS group is missing somehow, just use the initial one from the
      ## data pulled from the EDW
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(input$losGroup)
      }
      
      ## Ditto for the SC group
      if(is.null(isolate(gv$scgroup))){
        gv$scgroup <- isolate(rv$scgroup)
      }
      
      ## This is essentially abuse of the intersect() function, but it
      ## correctly and quickly pulls the predictive model information
      ## applicable to the patient being viewed. Also creates the time
      ## variable
      if(length(isolate(rv$scPred)) > 0){
        rv$scPred <- scPreds$yhat6[intersect(
                                     intersect(
                                       which(scPreds$scgroup == gv$scgroup),
                                       which(scPreds$msg == rv$msg)
                                     ),
                                     intersect(
                                       which(scPreds$cmg == rv$cmg),
                                       which(scPreds$longstay == gv$losgroup)
                                     )
                                   )
        ]
        isolate(rv$scPred <- rv$scPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        rv$scPred <- NA
      }
      
      ## Sets up appropraite dates to display on the chart for the prediction
      ## reactive value
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = isolate(rv$admit),
                              to = (rv$admit + length(rv$scPred)) - 1, by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$scPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }
      
      ## Sets up the palette reactive value, which I think I quit using a while
      ## ago
      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      ## Reactive values for the axes. These being reactive is actually quite
      ## important. As we want the context for the dates to change based on
      ## which patient is selected.
      rv$xAx <- list(range = c(isolate(rv$admit) - 1,
                               as.Date(
                                 Sys.Date(),
                                 format = '%Y-%m-%d',
                                 origin = '1970-01-01'
                               )
                    ),
                    title = 'Date',
                    tickfont = list(size = 24),
                    titlefont = list(size = 24)
      )
      ## Sets the options for the y-axis. Doesn't actually have to be reactive
      rv$yAx <- list(title = 'AQ - SC Scores',
                     range = c(minScoSC_all, maxScoSC_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    ## Otherwise, if there's no SC data to be displayed, get ready to show
    ## nothing but the goals (if any) and predictive model.
    }else{
      ## Create empty data.frame, except for time.
      rv$toPlot <- data.frame(assessmentDate = isolate(rv$admit),
                              sc = NA, bal = NA, uef = NA, swl = NA, fim = NA,
                              scSE = NA, balSE = NA, uefSE = NA, swlSE = NA,
                              fimSE = NA, time = 0
      )
      
      ## Set up the LoS group, SC group, predictive models, and axes as before
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(is.null(isolate(gv$scgroup))){
        gv$scgroup <- isolate(rv$scgroup)
        isolate(rv$scPred <- rv$scPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        if(!is.na(isolate(rv$cmg))){
          rv$scPred <- scPreds$yhat6[intersect(
                                       intersect(
                                         which(scPreds$scgroup == gv$scgroup),
                                         which(scPreds$msg == rv$msg)
                                       ),
                                       intersect(
                                         which(scPreds$cmg == rv$cmg),
                                         which(scPreds$longstay == gv$losgroup)
                                       )
                                     )
          ]
        }else{
          rv$scPred <- NA
        }
      }
      
      ## Additional formatting to the predictive curve for better plotting.
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = isolate(rv$admit),
                              to = (rv$admit + length(rv$scPred)) - 1, by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$scPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }
      
      ## Palette setup. I need to standardize the way I utilize the palette
      ## throughout the server file.
      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      ## Formatting for the axes.
      rv$xAx <- list(range = c(rv$admit - 1, as.Date(Sys.Date(),
                                                     format = '%Y-%m-%d',
                                                     origin = '1970-01-01'
                                             )
                     ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - SC Scores',
                     range = c(minScoSC_all, maxScoSC_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }

    ## Now that the AQ score and predictive model information have been set up
    ## to work and display properly once plotted, it's time to also set up the
    ## goal-specific information.
    ## If the patient is in the sitting balance group...
    if(isolate(gv$scgroup) == 1 && any(!is.na(rv$newGoalsSC))){
      ## The goal line data should be just the adjusted FIM goals with all
      ## other AQ-related data missing
      rv$fgLineDat <- matrix(c(rep(NA, 35), rv$newGoalsSC),
                             nrow = 1,
                             ncol = nrow(siBalPar)
      )
      ## The goal line itself is scored below
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(scModSiBal,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = siBalMeans, cov = scLTCovSiBal
                       )
                     )$F1
      )
    ## Otherwise, if they're in the standing balance group...
    }else if(isolate(gv$scgroup) == 2 && any(!is.na(isolate(rv$newGoalsSC)))){
      rv$fgLineDat <- matrix(c(rep(NA, 41), isolate(rv$newGoalsSC)),
                             nrow = 1,
                             ncol = nrow(stBalPar)
      )
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(scModStBal,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = stBalMeans, cov = scLTCovStBal
                       )
                     )$F1
      )
    ## Or, if they're in the walking balance group...
    }else if(isolate(gv$scgroup) == 3 && any(!is.na(rv$newGoalsSC))){
      rv$fgLineDat <- matrix(c(rep(NA, 40), rv$newGoalsSC),
                             nrow = 1,
                             ncol = nrow(waBalPar)
      )
      rv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(scModWaBal,
                               response.pattern = isolate(rv$fgLineDat),
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = waBalMeans, cov = scLTCovWaBal
                       )
                     )$F1
      )
    }else if(all(is.na(rv$newGoalsSC))){
      rv$fgLineDat <- NA
      rv$fgLine <- NA
    }
    
    ## This is some patchwork to further modify the x-axis when the user makes
    ## changes. I need to streamline all of this at some point. It's a bit of a
    ## convoluted workaround, but at least it runs fast.
    scPredFull <- isolate(rv$scPredAllG)
    if(nrow(scPredFull) > 0){
      scPredFull <- scPredFull[intersect(
                                 which(scPredFull$longstay == gv$losgroup),
                                 which(scPredFull$scgroup == gv$scgroup)),
      ]
      if(nrow(scPredFull) > 0){
        scPredFull$assessmentDate <- seq.Date(from = isolate(rv$admit),
                                              to = isolate(rv$admit + 50),
                                              by = 1
        )
      }else{
        scPredFull$assessmentDate <- NA
      }
    }else{
      scPredFull <- data.frame(time = NA, msg = NA, cmg = NA, scgroup = NA,
                               longstay = NA, yhat6 = NA, assessmentDate = NA
      )
    }
    
    ## Final axis setup. Again, I should streamline this.
    rv$xAx2 <- isolate(rv$xAx)
    if(!is.na(isolate(rv$admit))){
      if(any(!is.na(isolate(rv$toPlot)))){
        rv$xAx2$range <- c(rv$admit - 1,
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(scPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(isolate(rv$admit) - 1,
                           isolate(rv$admit) + 50
        )
      }
    }else{
      if(all(!is.na(rv$toPlot))){
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(scPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           as.Date(Sys.Date(),
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ) + 50
        )
      }
    }
    rv$yAx2 <- list(title = 'AQ - SC Scores',
                    range = c(minScoSC_all, maxScoSC_all),
                    tickfont = list(size = 24),
                    titlefont = list(size = 24)
    )
    
    ## Final formatting for the predictive model and the FIM -> AQ line;
    ## creates what is actually plotted.
    if(!is.na(isolate(rv$cmg)) && length(grep('Peds', isolate(rv$ms))) == 0){
      if(any(!is.na(isolate(rv$predPlot)))){
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$predPlot$assessmentDate[1],
                               to = rv$predPlot$assessmentDate[1] + 50,
                               by = 'day'
                             ),
                             Prediction = scPredFull$yhat6
        )
        isolate(rv$predPlotFull$fgLine <- rv$fgLine)
      }else{
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$xAx2$range[1] + 1,
                               to = rv$xAx2$range[2],
                               by = 'day'
                             ),
                             Prediction = scPredFull$yhat6
        )
        isolate(rv$predPlotFull$fgLine <- rv$fgLine)
      }
      isolate(
      if(isolate(gv$losgroup) %in% c(1, 2)){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 18)
        ] <- NA
      }else if(isolate(gv$losgroup) == 3){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 23)
        ] <- NA
      }else if(isolate(gv$losgroup) == 4){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 30)
        ] <- NA
      }else if(isolate(gv$losgroup) == 5){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 36)
        ] <- NA
      }
      )
    }else{
      rv$predPlotFull <- isolate(data.frame(
                                   assessmentDate = seq.Date(
                                     from = rv$xAx2$range[1] + 1,
                                     to = rv$xAx2$range[2],
                                     by = 'day'
                                   ),
                                   Prediction = NA
                                 )
      )
      isolate(rv$predPlotFull$fgLine <- rv$fgLine)
    }
    
    ## If there are no AQ data, set the range for the predictive model
    if(all(!is.na(rv$toPlot))){
      rv$xAx2$range[2] <- tail(
                            rv$predPlotFull$assessmentDate[
                              which(!is.na(rv$predPlotFull$Prediction))
                            ], 1
      )
    }
    
    if(!is.null(rv$scSco[[1]])){
      aqChange <- data.frame(
                    assessmentDate = isolate(rv$toPlot$assessmentDate),
                    scChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    balChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    uefChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    swlChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1))
      )
      patFIMSC <- isolate(rv$fimSCO[rv$fimSCO$FIN == rv$fin, ])
      if(nrow(patFIMSC) > 1){
        patFIMSC$saveDate <- c(0, rep(NA, nrow(patFIMSC) - 1))
        for(i in 2:nrow(patFIMSC)){
          patFIMSC$saveDate[i] <- ifelse(all(patFIMSC[i, 3:8] ==
                                             patFIMSC[i - 1, 3:8],
                                             na.rm = T
                                         ),
                                         0, 1
          )
        }
      }else if(nrow(patFIMSC) == 1){
        patFIMSC$saveDate <- 0
      }else if(nrow(patFIMSC) < 1){
        patFIMSC[1,] <- NA
        patFIMSC$MRN <- isolate(rv$row$MRN)
        patFIMSC$FIN <- isolate(rv$row$FIN)
      }
      if(nrow(rv$toPlot) > 1){
        aqImpFwd <- as.data.frame(apply(rv$toPlot[, 2:5], 2, repeat.before))
      }else{
        aqImpFwd <- isolate(rv$toPlot[, 2:5])
      }
      if(nrow(aqImpFwd) > 1){
        for(i in 2:nrow(aqImpFwd)){
          if(any(!is.na(aqImpFwd$sc))){
            aqChange$scChange[i] <- ifelse(!(aqImpFwd$sc[i] %in%
                                             aqImpFwd$sc[i - 1]
                                           ),
                                           1, 0
            )
          }else{
            aqChange$scChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$bal))){
            aqChange$balChange[i] <- ifelse(!(aqImpFwd$bal[i] %in%
                                              aqImpFwd$bal[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$balChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$uef))){
            aqChange$uefChange[i] <- ifelse(!(aqImpFwd$uef[i] %in%
                                              aqImpFwd$uef[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$uefChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$swl))){
            aqChange$swlChange[i] <- ifelse(!(aqImpFwd$swl[i] %in%
                                              aqImpFwd$swl[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$swlChange[i] <- 0
          }
        }
        if(any(patFIMSC$saveDate != 0)){
          aqChange <- merge(aqChange, patFIMSC[, c(9, 11)],
                            by = 'assessmentDate',
                            all.x = T
          )
          aqChange$saveDate[is.na(aqChange$saveDate)] <- 0
        }else{
          aqChange$saveDate <- 0
        }
        if(any(is.na(aqChange))){
          aqChange[is.na(aqChange)] <- 0
        }
        for(i in 1:nrow(aqChange)){
          aqChange$marker[i] <- ifelse(aqChange[i, 2] == 1 &&
                                       sum(aqChange[i, 3:5]) > 0 &&
                                       aqChange[i, 6] == 0,
                                       'diamond', 'circle'
          )
        }
        rv$toPlot$marker <- aqChange$marker
      }else{
        isolate(rv$toPlot$marker <- 'circle')
      }
    }
    
    if(!('marker' %in% colnames(rv$toPlot))){
      rv$toPlot$marker <- 'circle'
    }

    ## Now on to the actual plotting. This is what will be rendered on the TCC
    ## card. Plotly requires piping code via the magrittr() and dplyr()
    ## packages if you don't want to save the plot itself as an object. Saving
    ## it as an object requires holding the plot svg in memory, which can
    ## affect peformance. Within the plot_ly() and add_trace() functions the
    ## options are below. As a general rule with plotly, a tilde means that
    ## the data.frame set in the "data" option is being referenced, meaning
    ## that "data$column.name" doesn't have to be specified every time.
    ### data        = a data.frame containing the data to be plotted
    ### x           = the data.frame column from data to be plotted on the
    ###               horizontal axis
    ### y           = the data.frame column from data to be plotted on the
    ###               vertical axis
    ### type        = the plotly designation for the type of chart to be
    ###               plotted
    ### mode        = the elements of the plotly "type" to be plotted
    ### connectgaps = a plotly option for ensuring that noncontiguous data
    ###               (i.e., data not recorded on consecutive x-axis units)
    ###               will still be connected by the line
    ### line        = options for the visual appearance of the line
    ### text        = the text to be displayed when hovering over a point on
    ###               the chart
    ### name        = the main title displayed in the top margin of the chart
    ### hoverinfo   = what type of information should be displayed when the
    ###               user hovers on a point
    ### marker      = visual options for the points displayed on the chart
    ### showlegend  = logial; should the "trace" (line) be displayed in the
    ###               chart's legend?
    output$patTC <- renderPlotly({
      plot_ly(data = isolate(rv$toPlot),
              mode = 'lines+markers',
              type = 'scatter',
              x = ~assessmentDate,
              y = ~sc,
              connectgaps = T,
              line = list(color = isolate(rv$pal)[1],
                          width = 3,
                          dash = 'solid'
              ),
              text = ~paste('Day ',
                            assessmentDate,
                            ': ',
                            round(sc, 2),
                            sep = ''
              ),
              name = 'AQ - Self Care',
              hoverinfo = 'text',
              marker = list(symbol = ~marker,
                            size = 8,
                            opacity = 1,
                            color = isolate(rv$pal)[1]
              ),
              showlegend = T
      ) %>%
      add_trace(data = isolate(rv$toPlot),
                x = ~assessmentDate,
                y = ~bal,
                mode = 'lines+markers',
                connectgaps = T,
                line = list(color = isolate(rv$pal)[2],
                            width = 2,
                            dash = 'solid'
                ),
                text = ~paste(assessmentDate,
                              ': ',
                              round(bal, 2),
                              sep = ''
                ),
                name = 'AQ - Balance',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[2]
                ),
                showlegend = T
      ) %>%
      add_trace(data = isolate(rv$toPlot),
                x = ~assessmentDate,
                y = ~uef,
                connectgaps = T,
                mode = 'lines+markers',
                line = list(color = isolate(rv$pal)[3],
                            width = 2,
                            dash = 'solid'
                ),
                text = ~paste(assessmentDate,
                              ': ',
                              round(uef, 2),
                              sep = ''
                ),
                name = 'AQ - UE Function',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[3]
                ),
                showlegend = T
      ) %>%
      add_trace(data = isolate(rv$toPlot),
                x = ~assessmentDate,
                y = ~swl,
                connectgaps = T,
                mode = 'lines+markers',
                line = list(color = isolate(rv$pal)[4],
                            width = 2,
                            dash = 'solid'
                ),
                text = ~paste(assessmentDate,
                              ': ',
                              round(swl, 2),
                              sep = ''
                ),
                name = 'AQ - Swallowing',
                hoverinfo = 'text',
                visible = 'legendonly',
                marker = list(symbol = 'circle',
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[4]
                ),
                showlegend = T
      ) %>%
      add_trace(data = isolate(rv$predPlotFull),
                x = ~assessmentDate,
                y = ~Prediction,
                mode = 'lines+markers',
                connectgaps = T,
                line = list(color = isolate(rv$pal)[5],
                            dash = 'dash'
                ),
                text = ~paste(assessmentDate,
                              ': ',
                              round(Prediction, 2),
                              sep = ''
                ),
                marker = list(symbol = 'line-ns',
                              color = isolate(rv$pal)[5]
                ),
                hoverinfo = 'text',
                name = 'AQ - SC Prediction',
                showlegend = T
      ) %>%
      add_trace(data = isolate(rv$predPlotFull),
                y = ~isolate(rv$fgLine),
                x = ~assessmentDate,
                name = 'Goal → AQ',
                mode = 'lines+markers',
                line = list(color = isolate(rv$pal)[1],
                            dash = 'dash'
                ),
                text = ~paste('Goal → AQ: ', 
                              round(isolate(rv$fgLine), 2)
                ),
                marker = list(symbol = 'line-ns'),
                hoverinfo = 'text',
                showlegend = T
      ) %>%
      ## The above functions define what to plot and how to plot it. This part
      ## establishes the layout within the svg. The options used here are:
      ### xaxis      = the object (or a list of options) that defines the
      ###              x-axis
      ### yaxis      = the object (or a list of options) that defines the
      ###              y-axis
      ### legend     = options for the display of the legend
      ### hoverlabel = display options for informationd displayed on hover
      ### margin     = because it's an svg, padding doesn't always work as
      ###              intended; instead, we can add some padding to the margin
      ###              to add a certain number of pixels to each side of the
      ###              chart
      ### autosize   = logical; should the chart resize if the div containing
      ###              the svg is resized? Because I have JS to that allows
      ###              users to resize that div, this is pretty important
      layout(
        xaxis = isolate(rv$xAx2),
        yaxis = isolate(rv$yAx2),
        legend = list(orientation = 'h',
                      xanchor = 'center',
                      x = .5, y = 1.2,
                      font = list(size = 24)
        ),
        hoverlabel = list(font = list(size = 24)),
        margin = list(b = 100),
        autosize = T
      )
    })
  }
  
  ## TCC updating when mobility options are changed; see the _sc version of
  ## this function for markup on corresponding sections.
  initTC_mob <- function(toPlot, predPlot, fgLine, goalGroup, losGroup, xAx,
                         yAx, pal
                )
  {
    gv$bcTrans <- as.numeric(isolate(input$bcTrans))
    gv$tsTrans <- as.numeric(isolate(input$tsTrans))
    gv$tTrans <- as.numeric(isolate(input$tTrans))
    gv$locWalk <- as.numeric(isolate(input$locWalk))
    gv$locWheel <- as.numeric(isolate(input$locWheel))
    gv$locStairs <- as.numeric(isolate(input$locStairs))

    gv$bcTransR <- isolate(gv$bcTrans) - 1
    gv$tsTransR <- isolate(gv$tsTrans) - 1
    gv$tsTransR <- car::recode(isolate(gv$tsTransR),
                               "0=0;1=1;2=2;3=3;4=4;5=5;6=5;NA=NA"
    )
    gv$tTransR <- isolate(gv$tTrans) - 1
    gv$locWalkR <- isolate(gv$locWalk) - 1
    gv$locWheelR <- isolate(gv$locWheel) - 1
    gv$locStairsR <- isolate(gv$locStairs) - 1
    

    rv$newGoalsMob <- data.frame(bedChairTransfer = isolate(gv$bcTransR),
                           tubShowerTransfer = isolate(gv$tsTransR),
                           toiletTransfer = isolate(gv$tTransR),
                           locomotionWalk = isolate(gv$locWalkR),
                           locomotionWheel = isolate(gv$locWheelR),
                           locomotionStairs = isolate(gv$locStairsR)
    )

    gv$mobgroup <- as.numeric(isolate(input$walkLevel))
    gv$losgroup <- as.numeric(isolate(input$losGroup))
    
    if(dim(isolate(rv$mobData))[1] > 0 &&
       any(isolate(apply(rv$mobData[, 5:35], c(1, 2),
                         function(x) !is.na(x) && x < 10
                   )
       )))
    {
      if(any(c(isolate(uv$balmob_switch), isolate(uv$wc_switch),
               isolate(uv$xfer_switch), isolate(uv$cbp_switch)
             ) == 0
        ))
      {
        tempDat <- isolate(rv$mobData)
        if(isolate(uv$balmob_switch) == 0){
          tempDat[, c(5:21, 26:27, 29)] <- NA
        }
        if(isolate(uv$wc_switch) == 0){
          tempDat[, c(22, 28, 34)] <- NA
        }
        if(isolate(uv$xfer_switch) == 0){
          tempDat[, 31:32] <- NA
        }
        if(isolate(uv$cbp_switch) == 0){
          tempDat[, 23:25] <- NA
        }
        gv$mobSco <- scoFunMobFIM(data = tempDat,
                                  group = isolate(gv$mobgroup)
        )
      }else{
        gv$mobSco <- scoFunMobFIM(data = isolate(rv$mobData),
                                  group = isolate(gv$mobgroup)
        )
      }
    }else{
      gv$mobSco <- NULL
    }
    
    if(dim(isolate(gv$mobSco)[[3]])[1] == 0 &&
       !is.null(isolate(gv$mobSco)))
    {
      gv$mobSco <- NULL
    }
    
    if(!is.null(isolate(gv$mobSco))){
      gv$toPlot <- isolate(as.data.frame(gv$mobSco[[2]]))
      gv$toPlot$time <- rv$los - as.numeric(
                                   Sys.Date() -
                                   as.Date(gv$toPlot$assessmentDate)
                                 )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(length(isolate(gv$mobPred)) > 0){
        gv$mobPred <- mobPreds$yhat6[intersect(
                                       intersect(
                                         which(
                                           mobPreds$mobgroup == gv$mobgroup
                                         ),
                                         which(mobPreds$msg == rv$msg)
                                       ),
                                       intersect(
                                         which(
                                           mobPreds$cmg == rv$cmg
                                         ),
                                         which(
                                           mobPreds$longstay == gv$losgroup
                                         )
                                       )
                                     )
        ]
        isolate(gv$mobPred <- rv$mobPred[1:min((max(gv$toPlot$time) + 1), 51)])
      }else{
        gv$mobPred <- NA
      }
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = isolate(rv$admit),
                              to = (rv$admit + length(gv$mobPred)) - 1,
                              by = 1
        )
        gv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(gv$mobPred)
        )
      }else{
        predDates <- NA
        gv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }

      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'maroon', 'gray')]

      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                             ),
                  title = 'Date',
                  tickfont = list(size = 24),
                  titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Mob Scores',
                     range = c(minScoMob_all, maxScoMob_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }else{
      gv$toPlot <- data.frame(assessmentDate = isolate(rv$admit),
                              mob = NA, bal = NA, wc = NA, cbp = NA,
                              mobSE = NA, balSE = NA, wcSE = NA, cbpSE = NA,
                              time = 0
      )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(is.null(isolate(gv$mobgroup))){
        gv$mobgroup <- isolate(rv$mobgroup)
        gv$mobPred <- gv$mobPred[1:min((max(gv$toPlot$time) + 1), 51)]
      }else{
        if(!is.na(isolate(rv$cmg))){
          gv$mobPred <- mobPreds$yhat6[intersect(
                                         intersect(
                                           which(mobPreds$mobgroup ==
                                                   gv$mobgroup
                                           ),
                                           which(mobPreds$msg == rv$msg)
                                         ),
                                           intersect(
                                             which(mobPreds$cmg == rv$cmg),
                                             which(
                                               mobPreds$longstay == gv$losgroup
                                             )
                                           )
                                       )
          ]
        }else{
          rv$mobPred <- NA
        }
      }
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = isolate(rv$admit),
                              to = (rv$admit + length(gv$mobPred)) - 1,
                              by = 1
        )
        gv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$mobPred)
        )
      }else{
        predDates <- NA
        gv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }
      
      rv$xAx <- list(range = c(isolate(rv$admit) - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                             ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Mob Scores',
                     range = c(minScoMob_all, maxScoMob_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      
      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'maroon', 'gray')]
    }

    if(gv$mobgroup == 1 && any(!is.na(rv$newGoalsMob[c(1:3, 5)]))){
      gv$fgLineDat <- matrix(c(rep(NA, 11), rv$newGoalsMob[c(1:3, 5)]),
                             nrow = 1, ncol = nrow(wheelPar)
      )
      gv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(mobModWheel,
                               response.pattern = isolate(gv$fgLineDat),
                               method = 'MAP',
                               theta_lim = c(-6, 6),
                               mean = wheelMeans,cov = mobLTCovWheel
                       )
                     )$F1
      )
    }else if(gv$mobgroup == 2 && any(!is.na(rv$newGoalsMob))){
      gv$fgLineDat <- matrix(c(rep(NA, 17), isolate(rv$newGoalsMob)),
                             nrow = 1, ncol = nrow(bothPar)
      )
      gv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(mobModBoth,
                               response.pattern = isolate(gv$fgLineDat),
                               method = 'MAP',
                               theta_lim = c(-6, 6),
                               mean = bothMeans, cov = mobLTCovBoth
                       )
                     )$F1
      )
    }else if(gv$mobgroup == 3 && any(!is.na(rv$newGoalsMob))){
      gv$fgLineDat <- matrix(c(rep(NA, 15), isolate(rv$newGoalsMob)),
                             nrow = 1, ncol = nrow(walkPar)
      )
      gv$fgLine <- as.numeric(
                     as.data.frame(
                       fscores(mobModWalk,
                               response.pattern = isolate(gv$fgLineDat),
                               method = 'MAP',
                               theta_lim = c(-6, 6),
                               mean = walkMeans, cov = mobLTCovWalk)
                       )$F1
      )
    }else if(all(is.na(isolate(rv$newGoalsMob)))){
      gv$fgLineDat <- NA
      gv$fgLine <- NA
    }

    mobPredFull <- isolate(rv$mobPredAllG)
    if(nrow(mobPredFull) > 0){
      mobPredFull <- mobPredFull[intersect(
                                   which(mobPredFull$longstay == gv$losgroup),
                                   which(mobPredFull$mobgroup == gv$mobgroup)
                                 )
      , ]
      if(nrow(mobPredFull) > 0){
        mobPredFull$assessmentDate <- seq.Date(from = rv$admit,
                                               to = rv$admit + 50,
                                               by = 1
        )
      }else{
        mobPredFull$assessmentDate <- NA
      }
    }else{
      mobPredFull <- data.frame(time = NA, msg = NA, cmg = NA, mobgroup = NA,
                                longstay = NA, yhat6 = NA, assessmentDate = NA
      )
    }
    
    rv$xAx2 <- isolate(rv$xAx)
    if(!is.na(isolate(rv$admit))){
      if(any(!is.na(isolate(gv$toPlot)))){
        rv$xAx2$range <- c(rv$admit - 1,
                           max(tail(gv$toPlot$assessmentDate, 1) + 1,
                               tail(mobPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(isolate(rv$admit) - 1, isolate(rv$admit) + 50)
      }
    }else{
      if(all(!is.na(gv$toPlot))){
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           max(tail(gv$toPlot$assessmentDate, 1) + 1,
                               tail(mobPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           as.Date(Sys.Date(),
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ) + 50
        )
      }
    }

    rv$yAx2 <- list(title = 'AQ - Mob Scores',
                    range = c(minScoMob_all, maxScoMob_all),
                    tickfont = list(size = 24),
                    titlefont = list(size = 24)
    )

    if(!is.na(isolate(rv$cmg)) && length(grep('Peds', isolate(rv$ms))) == 0){
      if(any(!is.na(isolate(gv$predPlot)))){
        gv$predPlotFull <- data.frame(
                             assessmentDate = 
                               seq.Date(
                                 from = gv$predPlot$assessmentDate[1],
                                 to = gv$predPlot$assessmentDate[1] + 50,
                                 by = 'day'
                               )
                             ,
                             Prediction = mobPredFull$yhat6
        )
        isolate(gv$predPlotFull$fgLine <- gv$fgLine)
      }else{
        gv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                                                from = rv$xAx2$range[1] + 1,
                                                to = rv$xAx2$range[2],
                                                by = 'day'
                             ),
                             Prediction = mobPredFull$yhat6
        )
        isolate(gv$predPlotFull$fgLine <- gv$fgLine)
      }
      isolate(
      if(isolate(gv$losgroup) %in% c(1, 2)){
        gv$predPlotFull$Prediction[
          gv$predPlotFull$assessmentDate >
          (gv$predPlotFull$assessmentDate[1] + 18)
        ] <- NA
      }else if(isolate(gv$losgroup) == 3){
        gv$predPlotFull$Prediction[
          gv$predPlotFull$assessmentDate >
          (gv$predPlotFull$assessmentDate[1] + 23)
        ] <- NA
      }else if(isolate(gv$losgroup) == 4){
        gv$predPlotFull$Prediction[
          gv$predPlotFull$assessmentDate >
          (gv$predPlotFull$assessmentDate[1] + 30)
        ] <- NA
      }else if(isolate(gv$losgroup) == 5){
        gv$predPlotFull$Prediction[
          gv$predPlotFull$assessmentDate >
          (gv$predPlotFull$assessmentDate[1] + 36)
        ] <- NA
      }
      )
    }else{
      gv$predPlotFull <- data.frame(
                           assessmentDate = seq.Date(
                             from = rv$xAx2$range[1] + 1,
                             to = rv$xAx2$range[2],
                             by = 'day'
                           ),
                           Prediction = NA
      )
      isolate(gv$predPlotFull$fgLine <- gv$fgLine)
    }
    
    group <- isolate(gv$mobgroup)
    
    balwlk <- ifelse(group %in% c(NA, 1),
                     'AQ - Balance', 'AQ - Balance/Walking'
    )

    if(isolate(gv$mobgroup) != 1){
      isolate(gv$toPlot$cbp <- NA)
    }
    
    if(!is.null(rv$mobSco[[1]])){
      aqChange <- data.frame(
                    assessmentDate = isolate(gv$toPlot$assessmentDate),
                    mobChange = c(0, rep(NA, nrow(isolate(gv$toPlot)) - 1)),
                    balChange = c(0, rep(NA, nrow(isolate(gv$toPlot)) - 1)),
                    wcChange = c(0, rep(NA, nrow(isolate(gv$toPlot)) - 1)),
                    xferChange = c(0, rep(NA, nrow(isolate(gv$toPlot)) - 1)),
                    cbpChange = c(0, rep(NA, nrow(isolate(gv$toPlot)) - 1))
      )
      patFIMMob <- isolate(rv$fimMobO[rv$fimMobO$FIN == rv$fin, ])
      if(nrow(patFIMMob) > 1){
        patFIMMob$saveDate <- c(0, rep(NA, nrow(patFIMMob) - 1))
        for(i in 2:nrow(patFIMMob)){
          patFIMMob$saveDate[i] <- ifelse(all(patFIMMob[i, 3:8] ==
                                              patFIMMob[i - 1, 3:8],
                                              na.rm = T
                                          ),
                                          0, 1
          )
        }
      }else if(nrow(patFIMMob) == 1){
        patFIMMob$saveDate <- 0
      }else if(nrow(patFIMMob) < 1){
        patFIMMob[1,] <- NA
        patFIMMob$MRN <- isolate(rv$row$MRN)
        patFIMMob$FIN <- isolate(rv$row$FIN)
      }
      if(nrow(gv$toPlot) > 1){
        aqImpFwd <- as.data.frame(
                      apply(gv$toPlot[, c('mob', 'bal', 'wc', 'xfer', 'cbp')],
                            2, repeat.before
                      )
        )
      }else{
        aqImpFwd <- isolate(gv$toPlot[, c('mob', 'bal', 'wc', 'xfer', 'cbp')])
      }
      if(nrow(aqImpFwd) > 1){
        for(i in 2:nrow(aqImpFwd)){
          if(any(!is.na(aqImpFwd$mob))){
            aqChange$mobChange[i] <- ifelse(!(aqImpFwd$mob[i] %in%
                                              aqImpFwd$mob[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$mobChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$bal))){
            aqChange$balChange[i] <- ifelse(!(aqImpFwd$bal[i] %in%
                                              aqImpFwd$bal[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$balChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$wc))){
            aqChange$wcChange[i] <- ifelse(!(aqImpFwd$wc[i] %in%
                                             aqImpFwd$wc[i - 1]
                                           ),
                                           1, 0
            )
          }else{
            aqChange$wcChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$xfer))){
            aqChange$xferChange[i] <- ifelse(!(aqImpFwd$xfer[i] %in%
                                               aqImpFwd$xfer[i - 1]
                                             ),
                                             1, 0
            )
          }else{
            aqChange$xferChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$cbp))){
            aqChange$cbpChange[i] <- ifelse(!(aqImpFwd$cbp[i] %in%
                                              aqImpFwd$cbp[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$cbpChange[i] <- 0
          }
        }
        if(any(patFIMMob$saveDate != 0)){
          aqChange <- merge(aqChange, patFIMMob[, c(9:10)],
                            by = 'assessmentDate',
                            all.x = T
          )
          aqChange$saveDate[is.na(aqChange$saveDate)] <- 0
        }else{
          aqChange$saveDate <- 0
        }
        if(any(is.na(aqChange))){
          aqChange[is.na(aqChange)] <- 0
        }
        for(i in 1:nrow(aqChange)){
          aqChange$marker[i] <- ifelse(aqChange[i, 2] == 1 &&
                                       sum(aqChange[i, 3:6]) > 0 &&
                                       aqChange[i, 7] == 0,
                                       'diamond', 'circle'
          )
        }
        gv$toPlot$marker <- aqChange$marker
      }else{
        isolate(gv$toPlot$marker <- 'circle')
      }
    }
    
    if(!('marker' %in% colnames(rv$toPlot))){
      gv$toPlot$marker <- 'circle'
    }
    
    if(!is.null(rv$cmg)){
      output$patTC <- renderPlotly({
        plot_ly(data = gv$toPlot,
                mode = 'lines+markers',
                type = 'scatter',
                x = ~assessmentDate,
                y = ~mob,
                connectgaps = T,
                line = list(color = rv$pal[1],
                            width = 3,
                            dash = 'solid'
                ),
                text = ~paste('Day ',
                              assessmentDate,
                              ': ',
                              round(mob, 2),
                              sep = ''
                ),
                name = 'AQ - Mobility',
                hoverinfo = 'text',
                marker = list(symbol = ~marker,
                              size = 8,
                              opacity = 1,
                              color = isolate(rv$pal)[1]
                ),
                showlegend = T
        ) %>%
        add_trace(x = ~assessmentDate,
                  y = ~bal,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[2],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(bal, 2),
                                sep = ''
                  ),
                  name = balwlk,
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                opacity = 1,
                                color = isolate(rv$pal)[2]
                  ),
                  showlegend = T
        ) %>%
        add_trace(x = ~assessmentDate,
                  y = ~wc,
                  connectgaps = T,
                  mode = 'lines+markers',
                  line = list(color = rv$pal[3],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(wc, 2),
                                sep = ''
                  ),
                  name = 'AQ - Wheelchair',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                opacity = 1,
                                color = isolate(rv$pal)[3]
                  ),
                  showlegend = T
        ) %>%
        add_trace(x = ~assessmentDate,
                  y = ~xfer,
                  connectgaps = T,
                  mode = 'lines+markers',
                  line = list(color = rv$pal[4],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(xfer, 2),
                                sep = ''
                  ),
                  name = 'AQ - Bathroom Transfers',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                opacity = 1,
                                color = isolate(rv$pal)[4]
                  ),
                  showlegend = T
        ) %>%
        add_trace(x = ~assessmentDate,
                  y = ~cbp,
                  connectgaps = T,
                  mode = 'lines+markers',
                  line = list(color = rv$pal[5],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(cbp, 2),
                                sep = ''
                  ),
                  name = 'AQ - Changing Body Position',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                opacity = 1,
                                color = isolate(rv$pal)[5]
                  ),
                  showlegend = T
        ) %>%
        add_trace(data = gv$predPlotFull,
                  x = ~assessmentDate,
                  y = ~fgLine,
                  connectgaps = T,
                  name = 'Goal → AQ',
                  mode = 'lines+markers',
                  line = list(color = rv$pal[1],
                              dash = 'dash'
                  ),
                  text = ~paste('Goal → AQ: ', 
                                round(fgLine, 2)
                  ),
                  marker = list(symbol = 'line-ns'),
                  hoverinfo = 'text',
                  showlegend = T
        ) %>%
        add_trace(data = gv$predPlotFull,
                  x = ~assessmentDate,
                  y = ~Prediction,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[6],
                              dash = 'dash'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(Prediction, 2),
                                sep = ''
                  ),
                  marker = list(symbol = 'line-ns',
                                color = rv$pal[6]
                  ),
                  hoverinfo = 'text',
                  name = 'AQ - Mob Prediction',
                  showlegend = T
        ) %>%
        layout(
          xaxis = rv$xAx2,
          yaxis = rv$yAx2,
          legend = list(orientation = 'h',
                        xanchor = 'center',
                        x = .5, y = 1.2,
                        font = list(size = 24)
          ),
          hoverlabel = list(font = list(size = 24)),
          margin = list(b = 100)
        )
      })
    }else{
      reactive({
        output$patTC <- renderPlotly({
          plot_ly(data = gv$toPlot,
                  mode = 'lines+markers',
                  type = 'scatter',
                  x = ~assessmentDate,
                  y = ~mob,
                  connectgaps = T,
                  line = list(color = rv$pal[1],
                              width = 3,
                              dash = 'solid'
                  ),
                  text = ~paste('Day ',
                                assessmentDate,
                                ': ',
                                round(mob, 2),
                                sep = ''
                  ),
                  name = 'AQ - Mobility',
                  hoverinfo = 'text',
                  marker = list(symbol = ~marker,
                                size = 8,
                                opacity = 1,
                                color = isolate(rv$pal)[1]
                  ),
                  showlegend = T
          ) %>%
          add_trace(x = ~assessmentDate,
                    y = ~bal,
                    mode = 'lines+markers',
                    connectgaps = T,
                    line = list(color = rv$pal[2],
                                width = 2,
                                dash = 'solid'
                    ),
                    text = ~paste(assessmentDate,
                                  ': ',
                                  round(bal, 2),
                                  sep = ''
                    ),
                    name = balwlk,
                    hoverinfo = 'text',
                    visible = 'legendonly',
                    marker = list(symbol = 'circle',
                                  size = 8,
                                  opacity = 1,
                                  color = isolate(rv$pal)[2]
                    ),
                    showlegend = T
          ) %>%
          add_trace(x = ~assessmentDate,
                    y = ~wc,
                    connectgaps = T,
                    mode = 'lines+markers',
                    line = list(color = rv$pal[3],
                                width = 2,
                                dash = 'solid'
                    ),
                    text = ~paste(assessmentDate,
                                  ': ',
                                  round(wc, 2),
                                  sep = ''
                    ),
                    name = 'AQ - Wheelchair',
                    hoverinfo = 'text',
                    visible = 'legendonly',
                    marker = list(symbol = 'circle',
                                  size = 8,
                                  opacity = 1,
                                  color = isolate(rv$pal)[3]
                    ),
                    showlegend = T
          ) %>%
          add_trace(x = ~assessmentDate,
                    y = ~xfer,
                    connectgaps = T,
                    mode = 'lines+markers',
                    line = list(color = rv$pal[4],
                                width = 2,
                                dash = 'solid'
                    ),
                    text = ~paste(assessmentDate,
                                  ': ',
                                  round(xfer, 2),
                                  sep = ''
                    ),
                    name = 'AQ - Bathroom Transfers',
                    hoverinfo = 'text',
                    visible = 'legendonly',
                    marker = list(symbol = 'circle',
                                  size = 8,
                                  opacity = 1,
                                  color = isolate(rv$pal)[4]
                    ),
                    showlegend = T
          ) %>%
          add_trace(x = ~assessmentDate,
                    y = ~cbp,
                    connectgaps = T,
                    mode = 'lines+markers',
                    line = list(color = rv$pal[5],
                                width = 2,
                                dash = 'solid'
                    ),
                    text = ~paste(assessmentDate,
                                  ': ',
                                  round(cbp, 2),
                                  sep = ''
                    ),
                    name = 'AQ - Changing Body Position',
                    hoverinfo = 'text',
                    visible = 'legendonly',
                    marker = list(symbol = 'circle',
                                  size = 8,
                                  opacity = 1,
                                  color = isolate(rv$pal)[5]
                    ),
                    showlegend = T
          ) %>%
          add_trace(data = gv$predPlotFull,
                    x = ~assessmentDate,
                    y = ~fgLine,
                    connectgaps = T,
                    name = 'Goal → AQ',
                    mode = 'lines+markers',
                    line = list(color = rv$pal[1],
                                dash = 'dash'
                    ),
                    text = ~paste('Goal → AQ: ',
                                  round(fgLine, 2)
                    ),
                    marker = list(symbol = 'line-ns'),
                    hoverinfo = 'text',
                    showlegend = T
          ) %>%
          layout(
            xaxis = rv$xAx2,
            yaxis = rv$yAx2,
            legend = list(orientation = 'h',
                          xanchor = 'center',
                          x = .5, y = 1.2,
                          font = list(size = 24)
            ),
            hoverlabel = list(font = list(size = 24)),
            margin = list(b = 100)
          )
        })
      })
    }
  }
  
  ## Same as the prior two functions, but this is relevant to cognition.
  initTC_cog <- function(toPlot, predPlot, fgLine, goalGroup, losGroup, xAx,
                         yAx, pal)
  {
    gv$comp <- as.numeric(isolate(input$comp))
    gv$exp <- as.numeric(isolate(input$exp))
    gv$si <- as.numeric(isolate(input$si))
    gv$ps <- as.numeric(isolate(input$ps))
    gv$mem <- as.numeric(isolate(input$mem))
    
    gv$compR <- isolate(gv$comp) - 1
    gv$expR <- isolate(gv$exp) - 1
    gv$siR <- isolate(gv$si) - 1
    gv$psR <- isolate(gv$ps) - 1
    gv$memR <- isolate(gv$mem) - 1
    
    rv$newGoalsCog <- data.frame(comprehension = isolate(gv$compR),
                           expression = isolate(gv$expR),
                           socialInteraction = isolate(gv$siR),
                           problemSolving = isolate(gv$psR),
                           memory = isolate(gv$memR)
    )

    gv$coggroup <- as.numeric(isolate(input$cogDiag))
    gv$losgroup <- as.numeric(isolate(input$losGroup))
    
    if(dim(isolate(rv$cogData))[1] > 0 &&
       any(apply(rv$cogData[, 5:43], c(1, 2),
                 function(x) !is.na(x) && x < 10
       ))
    ){
      if(any(c(isolate(uv$com_switch), isolate(uv$wcom_switch),
               isolate(uv$comp_switch), isolate(uv$spe_switch),
               isolate(uv$mem_switch), isolate(uv$agi_switch)) == 0
         ))
      {
        tempDat <- isolate(rv$cogData)
        if(isolate(uv$com_switch) == 0){
          tempDat[, c(24:29, 33:35, 38)] <- NA
        }
        if(isolate(uv$wcom_switch) == 0){
          tempDat[, 30:32] <- NA
        }
        if(isolate(uv$comp_switch) == 0){
          tempDat[, 36:37] <- NA
        }
        if(isolate(uv$spe_switch) == 0){
          tempDat[, 20:23] <- NA
        }
        if(isolate(uv$mem_switch) == 0){
          tempDat[, c(5:10, 15, 17:19)] <- NA
        }
        if(isolate(uv$agi_switch) == 0){
          tempDat[, 11:14] <- NA
        }
        rv$cogSco <- scoFunCogFIM(data = tempDat, group = isolate(gv$coggroup))
      }else{
        rv$cogSco <- scoFunCogFIM(data = isolate(rv$cogData),
                                  group = isolate(gv$coggroup)
        )
      }
    }else{
      rv$cogSco <- NULL
    }
    
    if(dim(isolate(rv$cogSco)[[3]])[1] == 0 && !is.null(rv$cogSco)){
      rv$cogSco <- NULL
    }
    
    if(!is.null(isolate(rv$cogSco))){
      rv$toPlot <- isolate(as.data.frame(rv$cogSco[[2]]))
      rv$toPlot$time <- rv$los -
                        as.numeric(Sys.Date() -
                                   as.Date(rv$toPlot$assessmentDate)
                        )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      
      if(is.null(isolate(gv$coggroup))){
        gv$coggroup <- isolate(rv$coggroup)
      }
      
      if(length(isolate(rv$cogPred)) > 0){
        rv$cogPred <- cogPreds$yhat6[intersect(
                                       intersect(
                                         which(
                                           cogPreds$coggroup == gv$coggroup
                                         ),
                                         which(cogPreds$msg == isolate(rv$msg))
                                       ),
                                       intersect(
                                         which(cogPreds$cmg == rv$cmg),
                                         which(cogPreds$longstay ==
                                               gv$losgroup
                                         )
                                       )
                                     )
        ]
        isolate(rv$cogPred <- rv$cogPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        rv$cogPred <- NA
      }

      isolate(
      if(!is.na(gv$coggroup)){
        if(isolate(gv$coggroup) == 1){
          rv$toPlot$spe <- NA
          rv$toPlot$mem <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 2){
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 3){
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
        }else if(isolate(gv$coggroup) == 4){
          rv$toPlot$spe <- NA
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 5){
          rv$toPlot$mem <- NA
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }
      }
      )
      
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = isolate(rv$admit),
                              to = (rv$admit + length(rv$cogPred)) - 1,
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$cogPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }

      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      rv$xAx <- list(range = c(rv$admit - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                     ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Cog Scores',
                     range = c(minScoCog_all, maxScoCog_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }else{
      rv$toPlot <- data.frame(assessmentDate = rv$admit, cog = NA, com = NA,
                              spe = NA, wcom = NA, mem = NA, comp = NA,
                              agi = NA, cogSE = NA, comSE = NA, speSE = NA,
                              wcomSE = NA, memSE = NA, compSE = NA, agiSE = NA,
                              time = 0
      )
      
      if(is.null(isolate(gv$losgroup))){
        gv$losgroup <- isolate(rv$losgroup)
      }
      if(is.null(isolate(gv$coggroup))){
        gv$coggroup <- isolate(rv$coggroup)
        isolate(rv$cogPred <- rv$cogPred[1:min((max(rv$toPlot$time) + 1), 51)])
      }else{
        if(!is.na(isolate(rv$cmg))){
          rv$cogPred <- cogPreds$yhat6[intersect(
                                         intersect(
                                           which(cogPreds$coggroup ==
                                                 gv$coggroup
                                           ),
                                           which(cogPreds$msg == rv$msg)
                                         ),
                                         intersect(
                                           which(cogPreds$cmg == rv$cmg),
                                           which(cogPreds$longstay ==
                                                 gv$losgroup
                                           )
                                         )
                                       )
          ]
        }else{
          rv$cogPred <- NA
        }
      }
      
      isolate(
      if(!is.na(gv$coggroup)){
        if(isolate(gv$coggroup) == 1){
          rv$toPlot$spe <- NA
          rv$toPlot$mem <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 2){
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 3){
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
        }else if(isolate(gv$coggroup) == 4){
          rv$toPlot$spe <- NA
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }else if(isolate(gv$coggroup) == 5){
          rv$toPlot$mem <- NA
          rv$toPlot$com <- NA
          rv$toPlot$wcom <- NA
          rv$toPlot$comp <- NA
          rv$toPlot$agi <- NA
        }
      }
      )
      
      isolate(
      if(!is.na(isolate(rv$cmg))){
        predDates <- seq.Date(from = isolate(rv$admit),
                              to = as.Date(
                                     ifelse(length(isolate(rv$cogPred)) > 1,
                                            (isolate(rv$admit) +
                                               length(rv$cogPred)) - 1,
                                            isolate(rv$admit)
                                     )
                                   ),
                              by = 1
        )
        rv$predPlot <- data.frame(assessmentDate = predDates,
                                  Prediction = isolate(rv$cogPred)
        )
      }else{
        predDates <- NA
        rv$predPlot <- data.frame(assessmentDate = NA,
                                  Prediction = NA
        )
      }
      )
      
      rv$pal <- col[c('orange', 'red', 'yellow', 'purple', 'gray')]
      
      rv$xAx <- list(range = c(isolate(rv$admit) - 1,
                               as.Date(Sys.Date(),
                                       format = '%Y-%m-%d',
                                       origin = '1970-01-01'
                               )
                             ),
                     title = 'Date',
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
      rv$yAx <- list(title = 'AQ - Cog Scores',
                     range = c(minScoCog_all, maxScoCog_all),
                     tickfont = list(size = 24),
                     titlefont = list(size = 24)
      )
    }
    
    if(!is.na(isolate(gv$coggroup))){
      if(isolate(gv$coggroup) == 1 && any(!is.na(rv$newGoalsCog))){
        rv$fgLineDat <- matrix(c(rep(NA, 16), rv$newGoalsCog),
                               nrow = 1, ncol = nrow(aphPar)
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModAph,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = aphMeans, cov = cogLTCovAph
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 2 && any(!is.na(rv$newGoalsCog))){
        rv$fgLineDat <- matrix(c(rep(NA, 13), rv$newGoalsCog),
                               nrow = 1, ncol = nrow(ccdPar)
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModCCD,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = ccdMeans, cov = cogLTCovCCD
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 3 && any(!is.na(rv$newGoalsCog))){
        rv$fgLineDat <- matrix(c(rep(NA, 15), rv$newGoalsCog),
                               nrow = 1, ncol = nrow(biPar)
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModBI,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = biMeans, cov = cogLTCovBI
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 4 && any(!is.na(isolate(rv$newGoalsCog)))){
        rv$fgLineDat <- matrix(c(rep(NA, 11), isolate(rv$newGoalsCog)),
                               nrow = 1, ncol = nrow(rhdPar)
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModRHD,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = rhdMeans, cov = cogLTCovRHD
                                  )
                                )$F1
        )
      }else if(isolate(gv$coggroup) == 5 && any(!is.na(rv$newGoalsCog))){
        rv$fgLineDat <- matrix(c(rep(NA, 4), rv$newGoalsCog),
                               nrow = 1, ncol = nrow(spePar)
        )
        rv$fgLine <- as.numeric(as.data.frame(
                                  fscores(cogModSpe,
                                          response.pattern = rv$fgLineDat,
                                          method = 'MAP', theta_lim = c(-6, 6),
                                          mean = speMeans, cov = cogLTCovSpe
                                  )
                                )$F1
        )
      }else if(all(is.na(rv$newGoalsCog))){
        rv$fgLineDat <- NA
        rv$fgLine <- NA
      }
    }else{
      rv$fgLineDat <- NA
      rv$fgLine <- NA
    }
    
    cogPredFull <- isolate(rv$cogPredAllG)
    if(nrow(cogPredFull) > 0){
      cogPredFull <- cogPredFull[intersect(
                                   which(cogPredFull$longstay == gv$losgroup),
                                   which(cogPredFull$coggroup == gv$coggroup)
                                 )
      , ]
      if(nrow(cogPredFull) > 0){
        cogPredFull$assessmentDate <- seq.Date(from = rv$admit,
                                               to = rv$admit + 50,
                                               by = 1
        )
      }else{
        cogPredFull$assessmentDate <- NA
      }
    }else{
      cogPredFull <- data.frame(time = NA, msg = NA, cmg = NA, coggroup = NA,
                                longstay = NA, yhat6 = NA, assessmentDate = NA
      )
    }
    
    rv$xAx2 <- isolate(rv$xAx)
    if(!is.na(isolate(rv$admit))){
      if(any(!is.na(isolate(rv$toPlot)))){
        rv$xAx2$range <- c(rv$admit - 1,
                           max(tail(rv$toPlot$assessmentDate, 1) + 1,
                               tail(cogPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(isolate(rv$admit) - 1, isolate(rv$admit) + 50)
      }
    }else{
      if(all(!is.na(rv$toPlot))){
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           max(tail(isolate(rv$toPlot$assessmentDate), 1) + 1,
                               tail(cogPredFull$assessmentDate, 1),
                               na.rm = T
                           )
        )
      }else{
        rv$xAx2$range <- c(as.Date(Sys.Date() - 1,
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ),
                           as.Date(Sys.Date(),
                                   format = '%Y-%m-%d',
                                   origin = '1970-01-01'
                           ) + 50
        )
      }
    }
    
    rv$yAx2 <- list(title = 'AQ - Cog Scores',
                    range = c(minScoCog_all, maxScoCog_all),
                    tickfont = list(size = 24),
                    titlefont = list(size = 24)
    )
    
    if(!is.na(isolate(rv$cmg)) && length(grep('Peds', isolate(rv$ms))) == 0){
      if(any(!is.na(isolate(rv$predPlot)))){
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$predPlot$assessmentDate[1],
                               to = rv$predPlot$assessmentDate[1] + 50,
                               by = 'day'
                             ),
                             Prediction = cogPredFull$yhat6
        )
        isolate(rv$predPlotFull$fgLine <- rv$fgLine)
      }else{
        rv$predPlotFull <- data.frame(
                             assessmentDate = seq.Date(
                               from = rv$xAx2$range[1] + 1,
                               to = rv$xAx2$range[2],
                               by = 'day'
                             ),
                             Prediction = cogPredFull$yhat6
        )
        isolate(rv$predPlotFull$fgLine <- rv$fgLine)
      }
      
      if(isolate(gv$losgroup) %in% c(1, 2)){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 18)
        ] <- NA
      }else if(isolate(gv$losgroup) == 3){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 23)
        ] <- NA
      }else if(isolate(gv$losgroup) == 4){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 30)
        ] <- NA
      }else if(isolate(gv$losgroup) == 5){
        rv$predPlotFull$Prediction[rv$predPlotFull$assessmentDate >
                                   (rv$predPlotFull$assessmentDate[1] + 36)
        ] <- NA
      }
    }else{
      rv$predPlotFull <- data.frame(
                           assessmentDate = seq.Date(
                             from = rv$xAx2$range[1] + 1,
                             to = rv$xAx2$range[2],
                             by = 'day'
                           ),
                           Prediction = NA
      )
      isolate(rv$predPlotFull$fgLine <- rv$fgLine)
    }

    if(!('com' %in% colnames(isolate(rv$toPlot)))){
      isolate(rv$toPlot$com <- NA)
    }
    if(!('spe' %in% colnames(isolate(rv$toPlot)))){
      isolate(rv$toPlot$spe <- NA)
    }
    if(!('wcom' %in% colnames(isolate(rv$toPlot)))){
      isolate(rv$toPlot$wcom <- NA)
    }
    if(!('mem' %in% colnames(isolate(rv$toPlot)))){
      isolate(rv$toPlot$mem <- NA)
    }
    if(!('comp' %in% colnames(isolate(rv$toPlot)))){
      isolate(rv$toPlot$com <- NA)
    }
    if(!('agi' %in% colnames(isolate(rv$toPlot)))){
      isolate(rv$toPlot$agi <- NA)
    }
    
    if(!is.null(rv$cogSco[[1]])){
      aqChange <- data.frame(
                    assessmentDate = isolate(rv$toPlot$assessmentDate),
                    cogChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    memChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    speChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    agiChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    comChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    wcomChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1)),
                    compChange = c(0, rep(NA, nrow(isolate(rv$toPlot)) - 1))
      )
      patFIMCog <- isolate(rv$fimCogO[rv$fimCogO$FIN == rv$fin, ])
      if(nrow(patFIMCog) > 1){
        patFIMCog$saveDate <- c(0, rep(NA, nrow(patFIMCog) - 1))
        for(i in 2:nrow(patFIMCog)){
          patFIMCog$saveDate[i] <- ifelse(all(patFIMCog[i, 3:7] ==
                                              patFIMCog[i - 1, 3:7],
                                              na.rm = T
                                          ),
                                          0, 1
          )
        }
      }else if(nrow(patFIMCog) == 1){
        patFIMCog$saveDate <- 0
      }else if(nrow(patFIMCog) < 1){
        patFIMCog[1,] <- NA
        patFIMCog$MRN <- isolate(rv$row$MRN)
        patFIMCog$FIN <- isolate(rv$row$FIN)
      }
      if(nrow(rv$toPlot) > 1){
        aqImpFwd <- as.data.frame(
                      apply(rv$toPlot[, c('cog', 'mem', 'spe', 'agi', 'com',
                                          'wcom', 'comp'
                                        )
                            ],
                            2, repeat.before
                      )
        )
      }else{
        aqImpFwd <- isolate(rv$toPlot[, c('cog', 'mem', 'spe', 'agi', 'com',
                                          'wcom', 'comp'
                                        )
                            ]
        )
      }
      if(nrow(aqImpFwd) > 1){
        for(i in 2:nrow(aqImpFwd)){
          if(any(!is.na(aqImpFwd$cog))){
            aqChange$cogChange[i] <- ifelse(!(aqImpFwd$cog[i] %in%
                                              aqImpFwd$cog[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$cogChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$mem))){
            aqChange$memChange[i] <- ifelse(!(aqImpFwd$mem[i] %in%
                                              aqImpFwd$mem[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$memChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$spe))){
            aqChange$speChange[i] <- ifelse(!(aqImpFwd$spe[i] %in%
                                              aqImpFwd$spe[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$speChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$com))){
            aqChange$comChange[i] <- ifelse(!(aqImpFwd$com[i] %in%
                                              aqImpFwd$com[i - 1]
                                            ),
                                            1, 0
            )
          }else{
            aqChange$comChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$wcom))){
            aqChange$wcomChange[i] <- ifelse(!(aqImpFwd$wcom[i] %in%
                                               aqImpFwd$wcom[i - 1]
                                             ),
                                             1, 0
            )
          }else{
            aqChange$wcomChange[i] <- 0
          }
          if(any(!is.na(aqImpFwd$comp))){
            aqChange$compChange[i] <- ifelse(!(aqImpFwd$comp[i] %in%
                                               aqImpFwd$comp[i - 1]
                                             ),
                                             1, 0
            )
          }else{
            aqChange$compChange[i] <- 0
          }
        }
        if(any(patFIMCog$saveDate != 0)){
          aqChange <- merge(aqChange, patFIMCog[, c(8, 10)],
                            by = 'assessmentDate',
                            all.x = T
          )
          aqChange$saveDate[is.na(aqChange$saveDate)] <- 0
        }else{
          aqChange$saveDate <- 0
        }
        if(any(is.na(aqChange))){
          aqChange[is.na(aqChange)] <- 0
        }
        for(i in 1:nrow(aqChange)){
          aqChange$marker[i] <- ifelse(aqChange[i, 2] == 1 &&
                                       sum(aqChange[i, 3:8]) > 0 &&
                                       aqChange[i, 9] == 0,
                                       'diamond', 'circle'
          )
        }
        rv$toPlot$marker <- aqChange$marker
      }else{
        isolate(rv$toPlot$marker <- 'circle')
      }
    }
    
    if(!('marker' %in% colnames(rv$toPlot))){
      rv$toPlot$marker <- 'circle'
    }
    
    output$patTC <- renderPlotly({
      isolate(
      plot_ly(data = rv$toPlot,
              type = 'scatter',
              mode = 'lines+markers',
              x = ~assessmentDate,
              y = ~cog,
              connectgaps = T,
              line = list(color = rv$pal[1],
                          dash = 'solid'
              ),
              text = ~paste(assessmentDate, ': ', round(cog, 2), sep = ''),
              name = 'AQ - Cognition',
              hoverinfo = 'text',
              marker = list(symbol = ~marker,
                            size = 8,
                            color = isolate(rv$pal)[1]
              )
      ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~com,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[2],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(com, 2), sep = ''
                  ),
                  name = 'AQ - Communication',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[2]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~spe,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[2],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(spe, 2),
                                sep = ''
                  ),
                  name = 'AQ - Speech',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[2]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~wcom,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[3],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(wcom, 2),
                                sep = ''
                  ),
                  name = 'AQ - Writing',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[3]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~mem,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[3],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(mem, 2),
                                sep = ''
                  ),
                  name = 'AQ - Memory',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[3]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~comp,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[4],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(comp, 2),
                                sep = ''
                  ),
                  name = 'AQ - Comprehension',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[4]
                  )
        ) %>%
        add_trace(data = rv$toPlot,
                  x = ~assessmentDate,
                  y = ~agi,
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[4],
                              width = 2,
                              dash = 'solid'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(agi, 2),
                                sep = ''
                  ),
                  name = 'AQ - Agitation',
                  hoverinfo = 'text',
                  visible = 'legendonly',
                  marker = list(symbol = 'circle',
                                size = 8,
                                color = isolate(rv$pal)[4]
                  )
        ) %>%
        add_trace(data = rv$predPlotFull,
                  x = ~assessmentDate,
                  y = ~Prediction,
                  type = 'scatter',
                  mode = 'lines+markers',
                  connectgaps = T,
                  line = list(color = rv$pal[5],
                              dash = 'dash'
                  ),
                  text = ~paste(assessmentDate,
                                ': ',
                                round(Prediction, 2),
                                sep = ''
                  ),
                  marker = list(symbol = 'line-ns', color = rv$pal[5]),
                  hoverinfo = 'text',
                  name = 'AQ - Cog Prediction'
        ) %>%
        add_trace(data = rv$predPlotFull,
                  y = ~fgLine,
                  x = ~assessmentDate,
                  mode = 'lines+markers',
                  name = 'Goal → AQ',
                  line = list(color = rv$pal[1], dash = 'dash'),
                  text = ~paste('Goal → AQ: ', round(fgLine, 2)),
                  marker = list(symbol = 'line-ns'),
                  hoverinfo = 'text'
        ) %>%
        layout(
          xaxis = rv$xAx2,
          yaxis = rv$yAx2,
          legend = list(orientation = 'h',
                        xanchor = 'center',
                        x = .5, y = 1.2,
                        font = list(size = 24)
          ),
          hoverlabel = list(font = list(size = 24)),
          margin = list(b = 100)
        )
      )
    })
  }
  
  ## Handles the display of the TRC card. It is server side as many of the
  ## elements with which users interact require UI elements to be dynamically
  ## rendered. Because of this necessity, the function is mostly comprised of
  ## shiny/htmlWidgets HTML helper functions for writing HTML as R code.
  ## This function is invoked by the linePlot[SC/Mob/Cog] functions.
  ### goalDataRecode = the FIM-formatted goal data for the currently-displayed
  ###                  domain
  renderInit <- function(goalDataRecode){
    output$patProg <- renderUI({
      if(uv$dom == 'sc'){
        div(
            div(class = 'ui grid container',
                style = 'width: 100% !important;
                         margin-left: 5px;
                         margin-right: 5px;',
                div(class = 'four wide column',
                    style = 'font-size: 16px; width: 30% !important',
                    div(class = 'ui segment shadowed2',
                        style = 'border-radius: .28571429rem;
                                 padding: 1em;
                                 border: 0;',
                        HTML('<span class = "bold black"
                                    style = "font-size: 22px"
                              >
                                FIM Goals
                              </span>'
                        ),
                        br(),
                        div(class = 'row',
                            selectInput('eat', 'Eating',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsSC),
                                                          as.numeric(
                                                            goalDataRecode[1]
                                                          ),
                                                          gv$eat
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('groom', 'Grooming',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsSC),
                                                          as.numeric(
                                                            goalDataRecode[2]
                                                          ),
                                                          gv$groom
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('bath', 'Bathing',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsSC),
                                                          as.numeric(
                                                            goalDataRecode[3]
                                                          ),
                                                          gv$bath
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('ubDress', 'UB Dressing',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsSC),
                                                          as.numeric(
                                                            goalDataRecode[4]
                                                          ),
                                                          gv$ubDress
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('lbDress', 'LB Dressing',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsSC),
                                                          as.numeric(
                                                            goalDataRecode[5]
                                                          ),
                                                          gv$lbDress
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('toilet', 'Toileting',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsSC),
                                                          as.numeric(
                                                            goalDataRecode[6]
                                                          ),
                                                          gv$toilet
                                        )
                            )
                        )
                    ),
                    div(class = 'ui segment shadowed2',
                        style = 'border-radius: .28571429rem;
                                 padding: 1em; border: 0;',
                        HTML('<span class = "bold black"
                                    style = "font-size: 22px"
                              >
                                Patient Traits
                              </span>'
                        ),
                        br(),
                        div(class = 'row',
                            selectInput('balLevel', 'Expected balance level',
                                        c('Sitting (FIST)' = 1,
                                          'Standing (Berg)' = 2,
                                          'Walking (FGA)' = 3
                                        ),
                                        selected = isolate(gv$scgroup)
                            )
                        ),
                        div(class = 'row',
                            selectInput('losGroup', 'Expected LoS',
                                         c('3 - 18 days' = 2,
                                           '19 - 23 days' = 3,
                                           '24 - 30 days' = 4,
                                           '31 - 36 days' = 5,
                                           '36+ days' = 6
                                         ),
                                         selected = max(gv$losgroup, 2)
                            )
                        )
                    )
                ),
                div(class = 'twelve wide column',
                    style = 'width: 70% !important;',
                    div(class = 'row',
                        plotlyOutput('patTC', width = '100%', height = '700px')
                    )
                )
            ),
            div(class = 'ui grid container shadowed2',
                style = 'border-radius: .28571429rem; border: 0;',
                div(class = 'sixteen wide center aligned row',
                    div(class = 'eight wide center aligned column',
                      div(class = 'fluid orange ui button shadowed2',
                          id = 'updateITC_sc',
                          style = 'border-radius: .28571429rem;
                                   display: inline-block; width: 75%',
                          'Update Self Care Chart'
                      )
                    ),
                    div(class = 'eight wide center aligned column',
                      div(class = 'fluid red ui button shadowed2',
                          id = 'resetITC_sc',
                          style = 'border-radius: .28571429rem;
                                   display: inline-block; width: 75%',
                          'Reset Self Care Chart'
                      )
                    )
                )
            )
        )
      }else if(uv$dom == 'mob'){
        div(
            div(class = 'ui grid container',
                style = 'width: 100% !important;
                         margin-left: 5px;
                         margin-right: 5px;',
                div(class = 'four wide column',
                    style = 'font-size: 16px; width: 30% !important',
                    div(class = 'ui segment shadowed2',
                        style = 'border-radius: .28571429rem;
                                 padding: 1em; border: 0;',
                        HTML('<span class = "bold black"
                                    style = "font-size: 22px"
                              >
                                FIM Goals
                              </span>'
                        ),
                        br(),
                        div(class = 'row',
                            selectInput('bcTrans', 'Bed/Chair Transfer',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsMob),
                                                          as.numeric(
                                                            goalDataRecode[1]
                                                          ),
                                                          gv$bcTrans
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('tsTrans', 'Tub/Shower Transfer',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsMob),
                                                          as.numeric(
                                                            goalDataRecode[2]
                                                          ),
                                                          gv$tsTrans
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('tTrans', 'Toilet Transfer',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsMob),
                                                          as.numeric(
                                                            goalDataRecode[3]
                                                          ),
                                                          gv$tTrans
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('locWalk', 'Locomotion - Walking',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsMob),
                                                          as.numeric(
                                                            goalDataRecode[4]
                                                          ),
                                                          gv$locWalk
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('locWheel', 'Locomotion - Wheelchair',
                                        c('6' = 6, '5' = 5, '4' = 4, '3' = 3,
                                          '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsMob),
                                                          as.numeric(
                                                            goalDataRecode[5]
                                                          ),
                                                          gv$locWheel
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('locStairs', 'Locomotion - Stairs',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsMob),
                                                          as.numeric(
                                                            goalDataRecode[6]
                                                          ),
                                                          gv$locStairs
                                        )
                            )
                        )
                    ),
                    div(class = 'ui segment shadowed2',
                        style = 'border-radius: .28571429rem;
                                 padding: 1em; border: 0;',
                        HTML('<span class = "bold black"
                                    style = "font-size: 22px"
                              >
                                Patient Traits
                              </span>'
                        ),
                        br(),
                        div(class = 'row',
                            selectInput('walkLevel',
                                        'What is the patient\'s
                                         expected mode of locomotion?',
                                        c('Wheelchair' = 1,
                                          'Both' = 2,
                                          'Walking' = 3
                                        ),
                                        selected = isolate(gv$mobgroup)
                            )
                        ),
                        div(class = 'row',
                            selectInput('losGroup', 'Expected LoS',
                                         c('3 - 18 days' = 2,
                                           '19 - 23 days' = 3,
                                           '24 - 30 days' = 4,
                                           '31 - 36 days' = 5,
                                           '36+ days' = 6
                                         ),
                                         selected = max(gv$losgroup, 2)
                            )
                        )
                    )
                ),
                div(class = 'twelve wide column',
                    style = 'width: 70% !important;',
                    div(class = 'row',
                        plotlyOutput('patTC', width = '100%', height = '700px')
                    )
                )
            ),
            div(class = 'ui grid container shadowed2',
                style = 'border-radius: .28571429rem; border: 0;',
                div(class = 'sixteen wide center aligned row',
                    div(class = 'eight wide center aligned column',
                      div(class = 'fluid orange ui button shadowed2',
                          id = 'updateITC_mob',
                          style = 'border-radius: .28571429rem;
                                   display: inline-block; width: 75%',
                          'Update Mobility Chart'
                      )
                    ),
                    div(class = 'eight wide center aligned column',
                      div(class = 'fluid red ui button shadowed2',
                          id = 'resetITC_mob',
                          style = 'border-radius: .28571429rem;
                                   display: inline-block; width: 75%',
                          'Reset Mobility Chart'
                      )
                    )
                )
            )
        )
      }else if(uv$dom == 'cog'){
        div(
            div(class = 'ui grid container',
                style = 'width: 100% !important;
                         margin-left: 5px;
                         margin-right: 5px;',
                div(class = 'four wide column',
                    style = 'font-size: 16px; width: 30% !important',
                    div(class = 'ui segment shadowed2',
                        style = 'border-radius: .28571429rem;
                                 padding: 1em; border: 0;',
                        HTML('<span class = "bold black"
                                    style = "font-size: 22px"
                              >
                                FIM Goals
                              </span>'
                        ),
                        br(),
                        div(class = 'row',
                            selectInput('comp', 'Comprehension',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(
                                                     is.null(rv$newGoalsCog),
                                                     as.numeric(
                                                       goalDataRecode[1]
                                                     ) + 1,
                                                     gv$comp
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('exp', 'Expression',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(
                                                     is.null(rv$newGoalsCog),
                                                     as.numeric(
                                                       goalDataRecode[2]
                                                     ) + 1,
                                                     gv$exp
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('si', 'Social Interaction',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(
                                                     is.null(rv$newGoalsCog),
                                                     as.numeric(
                                                       goalDataRecode[3]
                                                     ) + 1,
                                                     gv$si
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('ps', 'Problem Solving',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(
                                                     is.null(rv$newGoalsCog),
                                                     as.numeric(
                                                       goalDataRecode[4]
                                                     ) + 1,
                                                     gv$ps
                                        )
                            )
                        ),
                        div(class = 'row',
                            selectInput('mem', 'Memory',
                                        c('7' = 7, '6' = 6, '5' = 5, '4' = 4,
                                          '3' = 3, '2' = 2, '1' = 1, 'NA' = NA
                                        ),
                                        selected = ifelse(is.null(rv$newGoalsCog),
                                                          as.numeric(
                                                            goalDataRecode[5]
                                                          ) + 1,
                                                          gv$mem
                                        )
                            )
                        )
                    ),
                    div(class = 'ui segment shadowed2',
                        style = 'border-radius: .28571429rem;
                                 padding: 1em; border: 0;',
                        HTML('<span class = "bold black"
                               style = "font-size: 22px"
                              >
                                Patient Traits
                              </span>'
                        ),
                        br(),
                        div(class = 'row',
                            selectInput('cogDiag',
                                        '(Most Severe) Cognitive Diagnosis',
                                        c('Aphasia' = 1,
                                          'Cognitive-Communication
                                           Deficits' = 2,
                                          'Cognitive-Communication
                                           Deficits (BI)' = 3,
                                          'Cognitive-Communication
                                           Deficits (RHD)' = 4,
                                          'Speech Disorder' = 5
                                        ),
                                        selected = as.numeric(gv$coggroup)
                            )
                        ),
                        div(class = 'row',
                            selectInput('losGroup', 'Expected LoS',
                                         c('3 - 18 days' = 2,
                                           '19 - 23 days' = 3,
                                           '24 - 30 days' = 4,
                                           '31 - 36 days' = 5,
                                           '36+ days' = 6
                                         ),
                                         selected = max(gv$losgroup, 2)
                            )
                        )
                    )
                ),
                div(class = 'twelve wide column',
                    style = 'width: 70% !important;',
                    div(class = 'row',
                        plotlyOutput('patTC', width = '100%', height = '700px')
                    )
                )
            ),
            div(class = 'ui grid container shadowed2',
                style = 'border-radius: .28571429rem; border: 0;',
                div(class = 'sixteen wide center aligned row',
                    div(class = 'eight wide center aligned column',
                      div(class = 'fluid orange ui button shadowed2',
                          id = 'updateITC_cog',
                          style = 'border-radius: .28571429rem;
                                   display: inline-block; width: 75%',
                          'Update Cognition Chart'
                      )
                    ),
                    div(class = 'eight wide center aligned column',
                      div(class = 'fluid red ui button shadowed2',
                          id = 'resetITC_cog',
                          style = 'border-radius: .28571429rem;
                                   display: inline-block; width: 75%',
                          'Reset Cognition Chart'
                      )
                    )
                )
            )
        )
      }
    })
  }

  ## This function is run when the reset button for the TRCs is pressed. It
  ## returns the display of the page to what it would look like just after
  ## the patient is selected from the "Select Patient" table. The only notable
  ## exception occurs when FIM values have been edited using the "Update FIM"
  ## functionality; it is assumed that those values were edited because
  ## outdated FIM levels were present, and the corrected data should take
  ## priority.
  resetITC <- function(){
    ## Nullify reactive values that are user-editable
    if(uv$dom == 'sc'){
      rv$newGoalsSC <- NULL
    }else if(uv$dom == 'mob'){
      rv$newGoalsMob <- NULL
    }else if(uv$dom == 'cog'){
      rv$newGoalsCog <- NULL
    }
    gv$losgroup <- NULL
    gv$scgroup <- NULL
    gv$mobgroup <- NULL
    gv$coggroup <- NULL
    uv$swl_switch <- 1
    uv$wc_switch <- 1
    ## Reset all predictive models
    rv$scPred <- scPreds$yhat6[intersect(
                                 intersect(
                                   which(scPreds$scgroup == rv$scgroup),
                                   which(scPreds$msg == rv$msg)
                                 ),
                                 intersect(
                                   which(scPreds$cmg == rv$cmg),
                                   which(scPreds$longstay == rv$losgroup)
                                 )
                               )
    ]
    rv$mobPred <- mobPreds$yhat6[intersect(
                                   intersect(
                                     which(mobPreds$mobgroup == rv$mobgroup),
                                     which(mobPreds$msg == rv$msg)
                                   ),
                                   intersect(
                                     which(mobPreds$cmg == rv$cmg),
                                     which(mobPreds$longstay == rv$losgroup)
                                   )
                                 )
    ]
    rv$cogPred <- cogPreds$yhat6[intersect(
                                   intersect(
                                     which(cogPreds$coggroup == rv$coggroup),
                                     which(cogPreds$msg == rv$msg)
                                   ),
                                   intersect(
                                     which(cogPreds$cmg == rv$cmg),
                                     which(cogPreds$longstay == rv$losgroup)
                                   )
                                 )
    ]
    ## Return scores to their previous state
    if(dim(rv$scData)[1] > 0){
      rv$scSco <- scoFunSCFIM(data = rv$scData, group = rv$scgroup)
    }else{
      rv$scSco <- NULL
    }
    if(dim(rv$mobData)[1] > 0){
      rv$mobSco <- scoFunMobFIM(data = rv$mobData, group = rv$mobgroup)
    }else{
      rv$mobSco <- NULL
    }
    if(dim(rv$cogData)[1] > 0){
      if(!is.na(isolate(rv$coggroup))){
        rv$cogSco <- scoFunCogFIM(data = rv$cogData, group = rv$coggroup)
      }else{
        rv$cogSco <- NULL
      }
    }else{
      rv$cogSco <- NULL
    }
    ## Run the event handler that will, in turn, replot the data for the
    ## appropriate domain.
    progPlotHandler()
  }
  
  ## See nullGoal
  nullProg <- function(axText, message){
    nullX <- list(range = c(0, 50),
                title = 'Date',
                zeroline = F
    )
    nullY <- list(title = axText,
                range = c(-4, 4),
                zeroline = F
    )
    
    nullDat <- data.frame(x = 25,
                          y = 0
    )
    
    output$patTC <- renderPlotly({
      plot_ly(data = nullDat,
              x = ~x,
              y = ~y,
              type = 'scatter',
              mode = 'text',
              text = message,
              textfont = list(color = '#000000', size = 16)
      ) %>%
        layout(
          xaxis = nullX,
          yaxis = nullY,
          hoverlabel = list(font = list(size = 16))
        )
    })
    
    output$patProg <- renderUI({
      plotlyOutput('patTC', height = '700px')
    })
  }
  
  ## A simple helper function to assist that's applied via shinyjs (in turn,
  ## using JS) to change the reactive value pertaining to domain.
  ### - val = the (character) value of the domain
  changeDom <- function(val){
    uv$dom <- val
  }
  
  ## Deprecated. Was used as a helper function when there were multiple
  ## selectable display formats for the Typical Recovery Curve section.
  ### - val = the (numeric) value for the TRC display
  changeProg <- function(val){
    uv$prog <- val
  }
  
  ## Deprecated. Was used as a helper function when there were multiple
  ## selectable display formats for the FIM Goals section.
  ### - val = the (numeric) value for the FG section.
  changeGoal <- function(val){
    uv$goal <- val
  }
  
  ## Produces the initial timeline when a patient is selected. Instead of
  ## having separate self-care, mobility, and cognition flavors of this
  ## function, it's all-in-one.
  improvementTL <- function(){
    ## Establish the current date, patient's admission date, and which LoS
    ## group they are part of
    curDate <- Sys.Date()
    admitDt <- isolate(rv$admit)
    LOSgroup <- isolate(rv$losgroup)
    ## Select the correct IRT parameters, item labels, and predictive modelling
    ## info depending on the chosen domain.
    if(isolate(uv$dom) == 'sc'){
      tv$fimPar <- tail(siBalBs, 6)
      tv$tlPreds <- isolate(rv$scPred51)
      tv$fimItems <- c('Eating', 'Grooming', 'Bathing', 'UB Dressing',
                       'LB Dressing', 'Toileting'
      )
    }else if(isolate(uv$dom) == 'mob'){
      if(isolate(rv$mobgroup) == 1){
        tv$fimPar <- tail(wheelBs, 4)
        tv$fimItems <- c('Bed/Chair Transfer', 'Tub/Shower Transfer',
                         'Toilet Transfer', 'Wheelchair'
        )
      }else{
        tv$fimPar <- tail(walkBs, 6)
        tv$fimItems <- c('Bed/Chair Transfer', 'Tub/Shower Transfer',
                         'Toilet Transfer', 'Walking', 'Wheelchair', 'Stairs'
        )
      }
      tv$tlPreds <- isolate(rv$mobPred51)
    }else if(isolate(uv$dom) == 'cog'){
      tv$fimPar <- tail(aphBs, 5)
      tv$tlPreds <- isolate(rv$cogPred51)
      tv$fimItems <- c('Comprehension', 'Expression', 'Social Interaction',
                       'Problem Solving', 'Memory'
      )
    }
    ## If the patient has a CMG/estimated CMG and they are not a Peds patient...
    if(!is.na(isolate(rv$cmg)) && isolate(rv$msg) != 'L'){
      ## If the domain isn't cog or, if it is, if the patient has a cognitive
      ## diagnosis...
      if(isolate(uv$dom) != 'cog' || !is.na(isolate(rv$coggroup))){
        ## This probably warrants some explanation. Going from the innermost
        ## function, this bit converts the scores associated with the
        ## predictive model/typical recovery curve into FIM functional levels,
        ## then transposes that matrix and converts the object to a data.frame.
        ## In effect, this gives us a mapping from the FIM to predictive model
        ## using IRT as an intermediary.
        tv$funLevels <- as.data.frame(
                          t(sapply(
                              tv$tlPreds, function(x) predGen(mapSco = x,
                                                              bs = tv$fimPar
                                                      )
                          ))
        )
        ## Trims the predictive model and functional levels to match the
        ## patient's LoS group.
        if(LOSgroup %in% c(1, 2)){
          tv$tlPreds <- tv$tlPreds[1:19]
          tv$funLevels <- tv$funLevels[1:19, ]
        }else if(LOSgroup == 3){
          tv$tlPreds <- tv$tlPreds[1:24]
          tv$funLevels <- tv$funLevels[1:24, ]
        }else if(LOSgroup == 4){
          tv$tlPreds <- tv$tlPreds[1:31]
          tv$funLevels <- tv$funLevels[1:31, ]
        }else if(LOSgroup == 5){
          tv$tlPreds <- tv$tlPreds[1:37]
          tv$funLevels <- tv$funLevels[1:37, ]
        }else if(LOSgroup == 6){
          tv$tlPreds <- tv$tlPreds
          tv$funLevels <- tv$funLevels
        }
        ## Add column names, a sequential time variable, and dates to the
        ## data.frame RV.
        isolate(colnames(tv$funLevels) <- tv$fimItems)
        isolate(tv$funLevels$time <- 1:length(tv$tlPreds))
        tv$funLevels$date <- seq(from = admitDt,
                                 to = admitDt + (length(tv$tlPreds) - 1),
                                 by = 1
        )
        ## Creates a "revised" set of functional levels; this is necessary
        ## because of the uncertainty of extreme categories in the self-care
        ## and mobility AQs.
        isolate(tv$funLevelsR <- tv$funLevels)
        colnames(tv$funLevelsR) <- c(paste0(tv$fimItems, '_r'), 'time', 'date')
      }
      ## If the selected domain is self-care...
      if(isolate(uv$dom) == 'sc'){
        ## The FIM levels in tv$funLevelsR at this point are in "IRT format",
        ## so it's necessary to convert them back into "FIM format."
        tv$funLevelsR[, 1] <- tv$funLevelsR[, 1] + 1
        tv$funLevelsR[, 2] <- car::recode(
          tv$funLevelsR[, 2],
          "0='1, 2, or 3'; 1='4'; 2 = '5'; 3 = '6'; 4 = '7'"
        )
        tv$funLevelsR[, 3] <- car::recode(
          tv$funLevelsR[, 3],
          "0 = '1'; 1 = '2'; 2 = '3'; 3 = '4'; 4 = '5'; 5 = '6 or 7'"
        )
        tv$funLevelsR[, 4] <- tv$funLevelsR[, 4] + 1
        tv$funLevelsR[, 5] <- car::recode(
          tv$funLevelsR[, 5],
          "0 = '1 or 2'; 1 = '3'; 2 = '4'; 3 = '5'; 4 = '6'; 5 = '7'"
        )
        tv$funLevelsR[, 6] <- car::recode(
          tv$funLevelsR[, 6],
          "0 = '1'; 1 = '2'; 2 = '3'; 3 = '4'; 4 = '5'; 5 = '6 or 7'"
        )
        ## This also warrants some explanation. The timevis function requires
        ## start and end dates for each "event" it contains. Using rle (i.e.,
        ## the "run length" function) makes it really easy to index when one
        ## event ends and another begins. This first part, however, is merely
        ## interested in determining how many rows we'll need to make the
        ## data.frame that will go into timevis()
        tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:6], 2,
                                           function(x) rle(x)$values
                                     )
        ))
        ## This second part determines which FIM levels the timevis function
        ## will have to display for each item
        tlLevels <- unlist(apply(tv$funLevelsR[, 1:6], 2,
                                 function(x) rle(x)$values
                           )
        )
        ## Now that it's established how many rows we'll need in our final
        ## data.frame and which levels we'll need, we can start building the
        ## contents of the data frame
        if(is.matrix(tlLevels)){
          tlLevels <- unlist(as.data.frame(tlLevels))
        }
        tlStarts <- rep(NA, tlRowLength)
        ## The k index kinda works like a cursor that moves down tlStarts
        ## when it needs to in the loop below.
        k <- 1
        ## Loop over first six columns of the funLevelsR data.frame where
        ## FIM functional levels are held.
        for(j in 1:6){
          ## Loop over the rows, starting at row 2.
          for(i in 2:nrow(isolate(tv$funLevelsR))){
            ## If the (specifically) second entry isn't equal to the first
            ## entry in the current column, record the corresponding date
            ## as both will be needed as start dates for tlStarts. Then,
            ## move the k "cursor" up two positions in tlStarts so that it's
            ## ready to overwrite the next NA.
            if(isolate(tv$funLevelsR)[i, j] !=
               isolate(tv$funLevelsR)[(i - 1), j] &&
               (i - 1) == 1
            ){
              tlStarts[c(k, (k + 1))] <- as.character(
                                           tv$funLevelsR$date[c((i - 1), i)]
              )
              k = k + 2
            ## Otherwise, if it isn't the second entry but the focal entry is
            ## different from the entry above it, just record the corresponding
            ## date and move the k cursor up one position in tlStarts.
            }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
              tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
              k <- k + 1
            ## Finally, if neither of those joint conditionals are true but
            ## i = 2, just record the starting date and move the k cursor. This
            ## ensures that even without expecting changes in the predictive
            ## model, the start date will always be recorded.
            }else if((i - 1) == 1){
              tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
              k <- k + 1
            }
          }
        }
        ## With the start dates established, they can be formatted into a nice
        ## date/time format for timevis.
        tlStarts <- as.Date(tlStarts)
        tlStarts <- paste(tlStarts, '00:00:00')
        tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
        ## Determine the run lengths for each item.
        tlEnds <- apply(isolate(tv$funLevelsR)[, 1:6], 2,
                        function(x) rle(x)$lengths
        )
        ## Both parts of the conditional here perform the same basic operation,
        ## but if tlEnds is returned as a matrix, it needs to be handled
        ## slightly differently. What that operation actually is a just a bit
        ## of a cheap trick to effeciently get the end dates. In essence, by
        ## taking the cumulative sums of the run lengths, we get an index that
        ## gives us the exact positions of the end dates we need.
        if(!is.matrix(tlEnds)){
          tlEnds <- tv$funLevelsR$date[
            unlist(lapply(apply(isolate(tv$funLevelsR)[, 1:6], 2,
                                function(x) rle(x)$lengths
                          ), cumsum
            ))
          ]
        }else{
          tlEnds <- tv$funLevelsR$date[
            unlist(lapply(as.data.frame(apply(isolate(tv$funLevelsR)[, 1:6], 2,
                                              function(x) rle(x)$lengths
                                        )), cumsum
                   ))
          ]
        }
        ## Now that we have the end dates as well, we can format them into nice
        ## date/times as well. The time stamp on these being right before
        ## midnight ensures no gap or overlap between bars on the timeline.
        tlEnds <- paste(tlEnds, '23:59:59')
        tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
        ## This will simply determine the number of rows each item will need in
        ## the data.frame we'll pass to timevis
        tlGroupLengths <- apply(tv$funLevels[, 1:6], 2,
                                function(x) length(rle(x)$values)
        )
        ## And this part places repeats the item label the appropriate number
        ## of times for that same matrix
        tlEat <- rep('eat', tlGroupLengths[1])
        tlGroom <- rep('groom', tlGroupLengths[2])
        tlBath <- rep('bath', tlGroupLengths[3])
        tlUBD <- rep('ubd', tlGroupLengths[4])
        tlLBD <- rep('lbd', tlGroupLengths[5])
        tlToilet <- rep('toilet', tlGroupLengths[6])
        tlGroup <- c(tlEat, tlGroom, tlBath, tlUBD, tlLBD, tlToilet)
        ## This builds the grouping data.frame timevis needs. Unlike the start
        ## and end times, this is much more simple.
        tv$groups <- data.frame(id = c('eat', 'groom', 'bath', 'ubd', 'lbd',
                                       'toilet'
                                ),
                                content = isolate(tv$fimItems)
        )
      ## The above logic repeats for mob and cog below
      }else if(isolate(uv$dom) == 'mob'){
        if(isolate(rv$mobgroup) %in% c(2, 3)){
          isolate(tv$funLevelsR[, 1] <- tv$funLevelsR[, 1] + 1)
          tv$funLevelsR[, 2] <- car::recode(
            tv$funLevelsR[, 2], "0='1';1='2'; 2 = '3';3='4';4='5';5='6 or 7'"
          )
          isolate(tv$funLevelsR[, 3:6] <- tv$funLevelsR[, 3:6] + 1)
          tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:6], 2,
                                             function(x) rle(x)$values
                                       )
          ))
          tlLevels <- unlist(apply(tv$funLevelsR[, 1:6], 2,
                                   function(x) rle(x)$values
                             )
          )
          if(is.matrix(tlLevels)){
            tlLevels <- unlist(as.data.frame(tlLevels))
          }
          tlStarts <- rep(NA, tlRowLength)
          k <- 1
          for(j in 1:6){
            for(i in 2:nrow(isolate(tv$funLevelsR))){
              if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j] &&
                 (i - 1) == 1
              ){
                tlStarts[c(k, (k + 1))] <- as.character(
                  tv$funLevelsR$date[c((i - 1), i)]
                )
                k = k + 2
              }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
                k <- k + 1
              }else if((i - 1) == 1){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
                k <- k + 1
              }
            }
          }
          tlStarts <- as.Date(tlStarts)
          tlStarts <- paste(tlStarts, '00:00:00')
          tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
          tlEnds <- apply(isolate(tv$funLevelsR)[, 1:6], 2,
                          function(x) rle(x)$lengths
          )
          if(!is.matrix(tlEnds)){
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(apply(isolate(tv$funLevelsR)[, 1:6], 2,
                                  function(x) rle(x)$lengths
                            ), cumsum
              ))
            ]
          }else{
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(as.data.frame(apply(tv$funLevelsR[, 1:6], 2,
                                                function(x) rle(x)$lengths
                                          )), cumsum
              ))
            ]
          }
          tlEnds <- paste(tlEnds, '23:59:59')
          tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
          tlGroupLengths <- apply(tv$funLevels[, 1:6], 2,
                                  function(x) length(rle(x)$values)
          )
          tlBCT <- rep('bct', tlGroupLengths[1])
          tlTST <- rep('tst', tlGroupLengths[2])
          tlTT <- rep('tt', tlGroupLengths[3])
          tlWalk <- rep('walk', tlGroupLengths[4])
          tlWheel <- rep('wheel', tlGroupLengths[5])
          tlStair <- rep('stair', tlGroupLengths[6])
          tlGroup <- c(tlBCT, tlTST, tlTT, tlWalk, tlWheel, tlStair)
          tv$groups <- data.frame(id = c('bct', 'tst', 'tt', 'walk', 'wheel',
                                         'stair'
                                  ),
                                  content = isolate(tv$fimItems)
          )
        }else if(isolate(rv$mobgroup == 1)){
          isolate(tv$funLevelsR[, 1] <- tv$funLevelsR[, 1] + 1)
          tv$funLevelsR[, 2] <- car::recode(
            tv$funLevelsR[, 2], "0='1';1='2';2='3';3='4';4='5';5='6 or 7'"
          )
          isolate(tv$funLevelsR[, 3] <- tv$funLevelsR[, 3] + 1)
          isolate(tv$funLevelsR[, 4] <- tv$funLevelsR[, 4] + 1)
          tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:4], 2,
                                             function(x) rle(x)$values
                                       )
          ))
          tlLevels <- unlist(apply(tv$funLevelsR[, 1:4], 2,
                                   function(x) rle(x)$values
          ))
          if(is.matrix(tlLevels)){
            tlLevels <- unlist(as.data.frame(tlLevels))
          }
          tlStarts <- rep(NA, tlRowLength)
          k <- 1
          for(j in 1:4){
            for(i in 2:nrow(isolate(tv$funLevelsR))){
              if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j] &&
                 (i - 1) == 1
              ){
                tlStarts[c(k, (k + 1))] <- as.character(
                  tv$funLevelsR$date[c((i - 1), i)]
                )
                k = k + 2
              }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
                k <- k + 1
              }else if((i - 1) == 1){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
                k <- k + 1
              }
            }
          }
          tlStarts <- as.Date(tlStarts)
          tlStarts <- paste(tlStarts, '00:00:00')
          tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
          tlEnds <- apply(tv$funLevelsR[, 1:4], 2, function(x) rle(x)$lengths)
          if(!is.matrix(tlEnds)){
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(apply(tv$funLevelsR[, 1:4], 2,
                                  function(x) rle(x)$lengths
                            ), cumsum
              ))
            ]
          }else{
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(as.data.frame(apply(tv$funLevelsR[, 1:4], 2,
                                                function(x) rle(x)$lengths
                                          )), cumsum
              ))
            ]
          }
          tlEnds <- paste(tlEnds, '23:59:59')
          tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
          tlGroupLengths <- apply(tv$funLevels[, 1:4], 2,
                                  function(x) length(rle(x)$values)
          )
          tlBCT <- rep('bct', tlGroupLengths[1])
          tlTST <- rep('tst', tlGroupLengths[2])
          tlTT <- rep('tt', tlGroupLengths[3])
          tlWheel <- rep('wheel', tlGroupLengths[4])
          tlGroup <- c(tlBCT, tlTST, tlTT, tlWheel)
          tv$groups <- data.frame(id = c('bct', 'tst', 'tt', 'wheel'),
                                  content = isolate(tv$fimItems)
          )
        }
      }else if(isolate(uv$dom) == 'cog'){
        if(!is.na(isolate(rv$coggroup))){
          tv$funLevelsR[, 1:5] <- apply(tv$funLevelsR[, 1:5], 2,
                                        function(x) as.character(x + 1)
          )
          tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:5], 2,
                                             function(x) rle(x)$values
                                       )
          ))
          tlLevels <- unlist(apply(tv$funLevelsR[, 1:5], 2,
                                   function(x) rle(x)$values
          ))
          if(is.matrix(tlLevels)){
            tlLevels <- unlist(as.data.frame(tlLevels))
          }
          tlStarts <- rep(NA, tlRowLength)
          k <- 1
          for(j in 1:5){
            for(i in 2:nrow(isolate(tv$funLevelsR))){
              if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j] &&
                 (i - 1) == 1
              ){
                tlStarts[c(k, (k + 1))] <- as.character(
                  tv$funLevelsR$date[c((i - 1), i)]
                )
                k = k + 2
              }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
                k <- k + 1
              }else if((i - 1) == 1){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
                k <- k + 1
              }
            }
          }
          tlStarts <- as.Date(tlStarts)
          tlStarts <- paste(tlStarts, '00:00:00')
          tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
          tlEnds <- apply(tv$funLevelsR[, 1:5], 2, function(x) rle(x)$lengths)
          if(!is.matrix(tlEnds)){
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(apply(tv$funLevelsR[, 1:5], 2,
                                  function(x) rle(x)$lengths
                            ), cumsum
              ))
            ]
          }else{
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(as.data.frame(apply(tv$funLevelsR[, 1:5], 2,
                                                function(x) rle(x)$lengths
                                          )), cumsum
              ))
            ]
          }
          tlEnds <- paste(tlEnds, '23:59:59')
          tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
          tlGroupLengths <- apply(tv$funLevels[, 1:5], 2,
                                  function(x) length(rle(x)$values)
          )
          tlComp <- rep('comp', tlGroupLengths[1])
          tlExp <- rep('exp', tlGroupLengths[2])
          tlSI <- rep('si', tlGroupLengths[3])
          tlPS <- rep('ps', tlGroupLengths[4])
          tlMem <- rep('mem', tlGroupLengths[5])
          tlGroup <- c(tlComp, tlExp, tlSI, tlPS, tlMem)
          tv$groups <- data.frame(id = c('comp', 'exp', 'si', 'ps', 'mem'),
                                  content = isolate(tv$fimItems)
          )
        }else{
          tlRowLength <- 5
          tlLevels <- c('', '', 'No predictive model available', '', '')
          tlStarts <- rep(isolate(rv$admit), 5)
          tlEnds <- rep(isolate(rv$admit) + 1, 5)
          tlGroup <- c('comp', 'exp', 'si', 'ps', 'mem')
          
          tv$groups <- data.frame(id = c('comp', 'exp', 'si', 'ps', 'mem'),
                               content = isolate(tv$fimItems)
          )
        }
      }
      ## Now that the proper timeline data have been created, we can format
      ## them nicely into a reactive data.frame and apply some style rules.
      tv$tlData <- data.frame(id = 1:tlRowLength,
                               content = tlLevels,
                               start = tlStarts,
                               end = tlEnds,
                               group = tlGroup
      )
      ## If there are timeline data to plot, apply this styling.
      if(isolate(uv$dom) != 'cog' || !is.na(isolate(rv$coggroup))){
        tv$tlData$style <- ifelse(tv$tlData$content == '1',
                                  'background-color: #861f41;
                                   border-color: #861f41;
                                   font-size: 16px;
                                   height: 100%;',
                             ifelse(tv$tlData$content == '1 or 2',
                                    'background-color: #ba1d37;
                                     border-color: #ba1d37;
                                     font-size: 16px;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '1, 2, or 3',
                                    'background-color: #c24662;
                                     border-color: #c24662;
                                     font-size: 16px;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '2',
                                    'background-color: #ed1c2c;
                                     border-color: #ed1c2c;
                                     font-size: 16px;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '3',
                                    'background-color: #6d2077;
                                     border-color: #6d2077;
                                     font-size: 16px;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '4',
                                    'background-color: #ffd100;
                                     border-color: #ffd100;
                                     font-size: 16px;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '5',
                                    'background-color: #ffa168;
                                     border-color: #ffa168;
                                     font-size: 16px;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '6',
                                    'background-color: #fc8e13;
                                     border-color: #fc8e13;
                                     font-size: 16px;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '6 or 7',
                                    'background-color: #f87d1a;
                                     border-color: #f87d1a;
                                     font-size: 16px;
                                     height: 100%;',
                                    'background-color: #f36b21;
                                     border-color: #f36b21;
                                     font-size: 16px;
                                     height: 100%;'
        )))))))))
      ## Otherwise, apply this styling
      }else{
        tv$nullCogTL <- 1
        tv$tlData$style <- 'background-color: #ffd100; border-color: #ffd100;'
      }
      
      tv$groups$style <- 'height: 40px;'
      
      ## This small bit of code draws the timeline
      output$timeline <- renderTimevis({
        timevis(data = isolate(tv$tlData), group = isolate(tv$groups),
                fit = T, options = list(stack = F, autoResize = T)
        )
      })
    ## Inside of this else statement are instructions for the function when
    ## no data are available.
    }else{
      if(isolate(uv$dom) == 'sc'){
        tv$groups <- data.frame(id = c('eat', 'groom', 'bath', 'ubd', 'lbd',
                                       'toilet'
                                ),
                                content = isolate(tv$fimItems)
        )
      }else if(uv$dom == 'mob'){
        if(rv$mobgroup == 1){
          tv$groups <- data.frame(id = c('bct', 'tst', 'tt', 'wheel'),
                               content = isolate(tv$fimItems)
          )
        }else{
          tv$groups <- data.frame(id = c('bct', 'tst', 'tt', 'walk', 'wheel',
                                         'stair'),
                                  content = isolate(tv$fimItems)
          )
        }
      }else{
          tv$groups <- data.frame(id = c('comp', 'exp', 'si', 'ps', 'mem'),
                                  content = isolate(tv$fimItems)
          )
      }
      
      tv$tlData <- data.frame(id = 1:nrow(tv$groups),
                              content = NA,
                              start = isolate(rv$admit),
                              end = isolate(rv$admit),
                              group = tv$groups$id,
                              style = 'background-color: rgba(0,0,0,0);'
      )
      
      tv$groups$style <- 'height: 40px;'
      
      output$timeline <- renderTimevis({
        timevis(data = isolate(tv$tlData), group = tv$groups, fit = T,
                options = list(stack = F, autoResize = T)
        )
      })
    }
    
    if(is.null(isolate(tv$losgroup))){
      tv$losgroup <- max(isolate(rv$losgroup), 2)
    }
    ## This creates the content of the Timeline card. It's basically just
    ## HTML with some CSS.
    output$patTL <- renderUI({
      div(
        div(class = 'ui three column grid',
            style = 'width: 100%; margin-bottom: 1em; padding-bottom: 0px;',
            div(class = 'row',
                style = 'padding-top: 0px; padding-bottom: 0px;',
                div(class = 'content',
                    style = 'width: 100%; height: 100%; font-size: 20px;',
                    id = 'tlContainer',
                    timevisOutput('timeline', width = '100%')
                )
            )
        ),
        div(class = 'ui sixteen column grid shadowed2',
            style = 'border-radius: .28571429rem;
                     margin-top: 0px; padding-bottom: 0px;',
          div(class = 'eight wide center aligned row',
              style = 'padding-bottom: 0px;',
              div(class = 'right aligned two wide column',
                  style = 'vertical-align: middle; padding-top: 1em;
                           padding-right: 0em; max-height: 5em;',
                  div(class = 'row',
                      HTML('<div style = "font-weight: bold; color: #1b1c1d;">
                              Expected LoS:
                            </div>'
                      )
                  )
              ),
              div(class = 'seven wide center aligned column',
                  style = 'margin: 0px; vertical-align: middle;
                           padding-top: 0.25em; max-height: 5em;',
                  selectInput('ExpLoS', label = NULL,
                              c('3 - 18 days' = 2,
                                '19 - 23 days' = 3,
                                '24 - 30 days' = 4,
                                '31 - 36 days' = 5,
                                '36+ days' = 6
                              ),
                              selected = tv$losgroup
                  )
              ),
              div(class = 'six wide center aligned column',
                  style = 'padding-top: 0px;',
                  div(class = 'fluid orange ui button shadowed2',
                      id = 'updateTL',
                      style = 'border-radius: .28571429rem;
                               padding-top: 1em;',
                      'Update Timeline'
                  )
              )
          )
        )
      )
    })
  }
  
  ## This function handles updates to the timeline when a patient's
  ## domain-specific grouping and/or LoS group have changed. It's essentially
  ## identical to improvementTL() but includes handling for the relevant
  ## reactive values.
  renderTL <- function(){
    if(!is.na(isolate(rv$cmg)) && isolate(rv$msg) != 'L'){
      if(isolate(uv$dom) == 'sc'){
        tv$scgroup <- as.numeric(isolate(input$balLevel))
        tv$fimPar <- tail(siBalBs, 6)
        tv$tlPreds <- scPreds$yhat6[
          intersect(
            intersect(which(scPreds$scgroup == tv$scgroup),
                      which(scPreds$msg == rv$msg)
            ),
            intersect(which(scPreds$cmg == rv$cmg),
                      which(scPreds$longstay == tv$losgroup)
            )
          )
        ]
        tv$fimItems <- c('Eating', 'Grooming', 'Bathing', 'UB Dressing',
                         'LB Dressing', 'Toileting'
        )
      }else if(isolate(uv$dom) == 'mob'){
        tv$mobgroup <- as.numeric(isolate(input$walkLevel))
        if(isolate(tv$mobgroup) == 1){
          tv$fimPar <- tail(wheelBs, 4)
          tv$fimItems <- c('Bed/Chair Transfer', 'Tub/Shower Transfer',
                           'Toilet Transfer', 'Wheelchair'
          )
        }else{
          tv$fimPar <- tail(walkBs, 6)
          tv$fimItems <- c('Bed/Chair Transfer', 'Tub/Shower Transfer',
                           'Toilet Transfer', 'Walking', 'Wheelchair', 'Stairs'
          )
        }
        tv$tlPreds <- mobPreds$yhat6[
          intersect(
            intersect(which(mobPreds$mobgroup == tv$mobgroup),
                      which(mobPreds$msg == rv$msg)
            ),
            intersect(which(mobPreds$cmg == rv$cmg),
                      which(mobPreds$longstay == tv$losgroup)
            )
          )
        ]
      }else if(isolate(uv$dom) == 'cog'){
        tv$coggroup <- as.numeric(isolate(input$cogDiag))
        tv$fimPar <- tail(aphBs, 5)
        tv$tlPreds <- cogPreds$yhat6[
          intersect(
            intersect(which(cogPreds$coggroup == tv$coggroup),
                      which(cogPreds$msg == rv$msg)
            ),
            intersect(which(cogPreds$cmg == rv$cmg),
                      which(cogPreds$longstay == tv$losgroup)
            )
          )
        ]
        tv$fimItems <- c('Comprehension', 'Expression', 'Social Interaction',
                         'Problem Solving', 'Memory'
        )
      }
      
      curDate <- Sys.Date()
      admitDt <- isolate(rv$admit)
      LOSgroup <- input$ExpLoS
      
      if(isolate(uv$dom) != 'cog' || !is.na(isolate(rv$coggroup))){
        tv$funLevels <- as.data.frame(
                          t(sapply(tv$tlPreds, function(x)
                            predGen(mapSco = x, bs = tv$fimPar)
                          ))
        )
        if(LOSgroup %in% c(1, 2)){
          tv$tlPreds <- tv$tlPreds[1:19]
          tv$funLevels <- tv$funLevels[1:19, ]
        }else if(LOSgroup == 3){
          tv$tlPreds <- tv$tlPreds[1:24]
          tv$funLevels <- tv$funLevels[1:24, ]
        }else if(LOSgroup == 4){
          tv$tlPreds <- tv$tlPreds[1:31]
          tv$funLevels <- tv$funLevels[1:31, ]
        }else if(LOSgroup == 5){
          tv$tlPreds <- tv$tlPreds[1:37]
          tv$funLevels <- tv$funLevels[1:37, ]
        }else if(LOSgroup == 6){
          tv$tlPreds <- tv$tlPreds
          tv$funLevels <- tv$funLevels
        }

        isolate(colnames(tv$funLevels) <- tv$fimItems)
        isolate(tv$funLevels$time <- 1:length(tv$tlPreds))
        tv$funLevels$date <- seq(from = admitDt,
                                 to = admitDt + (length(tv$tlPreds) - 1),
                                 by = 1
        )
  
        isolate(tv$funLevelsR <- tv$funLevels)
        colnames(tv$funLevelsR) <- c(paste0(tv$fimItems, '_r'), 'time', 'date')
      }
      

      if(isolate(uv$dom) == 'sc'){
        isolate(tv$funLevelsR[, 1] <- tv$funLevelsR[, 1] + 1)
        tv$funLevelsR[, 2] <- car::recode(
          tv$funLevelsR[, 2], "0='1, 2, or 3';1='4';2='5';3='6';4 ='7'"
        )
        tv$funLevelsR[, 3] <- car::recode(
          tv$funLevelsR[, 3], "0 ='1';1='2';2='3';3='4';4='5';5 ='6 or 7'"
        )
        isolate(tv$funLevelsR[, 4] <- tv$funLevelsR[, 4] + 1)
        tv$funLevelsR[, 5] <- car::recode(
          tv$funLevelsR[, 5], "0 ='1 or 2';1='3';2='4';3='5';4='6';5='7'"
        )
        tv$funLevelsR[, 6] <- car::recode(
          tv$funLevelsR[, 6], "0='1';1='2';2='3';3='4';4='5';5='6 or 7'"
        )
        tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:6], 2,
                                           function(x) rle(x)$values
                                     )
        ))
        tlLevels <- unlist(apply(tv$funLevelsR[, 1:6], 2,
                                 function(x) rle(x)$values
        ))
        if(is.matrix(tlLevels)){
          tlLevels <- unlist(as.data.frame(tlLevels))
        }
        tlStarts <- rep(NA, tlRowLength)
        k <- 1
        for(j in 1:6){
          for(i in 2:nrow(isolate(tv$funLevelsR))){
            if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j] &&
               (i - 1) == 1
            ){
              tlStarts[c(k, (k + 1))] <- as.character(
                tv$funLevelsR$date[c((i - 1), i)]
              )
              k = k + 2
            }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
              tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
              k <- k + 1
            }else if((i - 1) == 1){
              tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
              k <- k + 1
            }
          }
        }
        tlStarts <- as.Date(tlStarts)
        tlStarts <- paste(tlStarts, '00:00:00')
        tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
        tlEnds <- apply(isolate(tv$funLevelsR)[, 1:6], 2,
                        function(x) rle(x)$lengths
        )
        if(!is.matrix(tlEnds)){
          tlEnds <- tv$funLevelsR$date[
            unlist(lapply(apply(tv$funLevelsR[, 1:6], 2,
                                function(x) rle(x)$lengths
                          ), cumsum
            ))
          ]
        }else{
          tlEnds <- tv$funLevelsR$date[
            unlist(lapply(as.data.frame(apply(tv$funLevelsR[, 1:6], 2,
                                              function(x) rle(x)$lengths
                          )), cumsum
            ))
          ]
        }
        tlEnds <- paste(tlEnds, '23:59:59')
        tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
        tlGroupLengths <- apply(tv$funLevels[, 1:6], 2,
                                function(x) length(rle(x)$values)
        )
        tlEat <- rep('eat', tlGroupLengths[1])
        tlGroom <- rep('groom', tlGroupLengths[2])
        tlBath <- rep('bath', tlGroupLengths[3])
        tlUBD <- rep('ubd', tlGroupLengths[4])
        tlLBD <- rep('lbd', tlGroupLengths[5])
        tlToilet <- rep('toilet', tlGroupLengths[6])
        tlGroup <- c(tlEat, tlGroom, tlBath, tlUBD, tlLBD, tlToilet)
        tv$groups <- data.frame(id = c('eat', 'groom', 'bath', 'ubd', 'lbd',
                                       'toilet'
                                ),
                                content = tv$fimItems
        )
      }else if(isolate(uv$dom) == 'mob'){
        if(isolate(tv$mobgroup) %in% c(2, 3)){
          isolate(tv$funLevelsR[, 1] <- tv$funLevelsR[, 1] + 1)
          tv$funLevelsR[, 2] <- car::recode(
            tv$funLevelsR[, 2], "0='1';1='2';2='3';3='4';4='5';5='6 or 7'"
          )
          isolate(tv$funLevelsR[, 3:6] <- tv$funLevelsR[, 3:6] + 1)
          tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:6], 2,
                                             function(x) rle(x)$values
                                       )
          ))
          tlLevels <- unlist(apply(tv$funLevelsR[, 1:6], 2,
                                   function(x) rle(x)$values
          ))
          if(is.matrix(tlLevels)){
            tlLevels <- unlist(as.data.frame(tlLevels))
          }
          tlStarts <- rep(NA, tlRowLength)
          k <- 1
          for(j in 1:6){
            for(i in 2:nrow(isolate(tv$funLevelsR))){
              if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j] &&
                 (i - 1) == 1
              ){
                tlStarts[c(k, (k + 1))] <- as.character(
                  tv$funLevelsR$date[c((i - 1), i)]
                )
                k = k + 2
              }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
                k <- k + 1
              }else if((i - 1) == 1){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
                k <- k + 1
              }
            }
          }
          tlStarts <- as.Date(tlStarts)
          tlStarts <- paste(tlStarts, '00:00:00')
          tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
          tlEnds <- apply(tv$funLevelsR[, 1:6], 2, function(x) rle(x)$lengths)
          if(!is.matrix(tlEnds)){
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(apply(tv$funLevelsR[, 1:6], 2,
                                  function(x) rle(x)$lengths
                            ), cumsum
              ))
            ]
          }else{
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(as.data.frame(apply(tv$funLevelsR[, 1:6], 2,
                                                function(x) rle(x)$lengths
                            )), cumsum
              ))
            ]
          }
          tlEnds <- paste(tlEnds, '23:59:59')
          tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
          tlGroupLengths <- apply(tv$funLevels[, 1:6], 2,
                                  function(x) length(rle(x)$values)
          )
          tlBCT <- rep('bct', tlGroupLengths[1])
          tlTST <- rep('tst', tlGroupLengths[2])
          tlTT <- rep('tt', tlGroupLengths[3])
          tlWalk <- rep('walk', tlGroupLengths[4])
          tlWheel <- rep('wheel', tlGroupLengths[5])
          tlStair <- rep('stair', tlGroupLengths[6])
          tlGroup <- c(tlBCT, tlTST, tlTT, tlWalk, tlWheel, tlStair)
          tv$groups <- data.frame(id = c('bct', 'tst', 'tt', 'walk', 'wheel',
                                         'stair'
                                  ),
                                  content = tv$fimItems
          )
        }else if(isolate(tv$mobgroup == 1)){
          isolate(tv$funLevelsR[, 1] <- tv$funLevelsR[, 1] + 1)
          tv$funLevelsR[, 2] <- car::recode(
            tv$funLevelsR[, 2], "0 ='1';1='2';2='3';3='4';4='5';5='6 or 7'"
          )
          isolate(tv$funLevelsR[, 3:4] <- tv$funLevelsR[, 3:4] + 1)
          tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:4], 2,
                                             function(x) rle(x)$values
                                       )
          ))
          tlLevels <- unlist(apply(tv$funLevelsR[, 1:4], 2,
                                   function(x) rle(x)$values
          ))
          if(is.matrix(tlLevels)){
            tlLevels <- unlist(as.data.frame(tlLevels))
          }
          tlStarts <- rep(NA, tlRowLength)
          k <- 1
          for(j in 1:4){
            for(i in 2:nrow(isolate(tv$funLevelsR))){
              if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j] &&
                 (i - 1) == 1
              ){
                tlStarts[c(k, (k + 1))] <- as.character(
                  tv$funLevelsR$date[c((i - 1), i)]
                )
                k = k + 2
              }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
                k <- k + 1
              }else if((i - 1) == 1){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
                k <- k + 1
              }
            }
          }
          tlStarts <- as.Date(tlStarts)
          tlStarts <- paste(tlStarts, '00:00:00')
          tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
          tlEnds <- apply(tv$funLevelsR[, 1:4], 2, function(x) rle(x)$lengths)
          if(!is.matrix(tlEnds)){
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(apply(tv$funLevelsR[, 1:4], 2,
                                  function(x) rle(x)$lengths
                            ), cumsum
              ))
            ]
          }else{
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(as.data.frame(apply(tv$funLevelsR[, 1:4], 2,
                                                function(x) rle(x)$lengths
                                          )), cumsum
              ))
            ]
          }
          tlEnds <- paste(tlEnds, '23:59:59')
          tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
          tlGroupLengths <- apply(tv$funLevels[, 1:4], 2,
                                  function(x) length(rle(x)$values)
          )
          tlBCT <- rep('bct', tlGroupLengths[1])
          tlTST <- rep('tst', tlGroupLengths[2])
          tlTT <- rep('tt', tlGroupLengths[3])
          tlWheel <- rep('wheel', tlGroupLengths[4])
          tlGroup <- c(tlBCT, tlTST, tlTT, tlWheel)
          tv$groups <- data.frame(id = c('bct', 'tst', 'tt', 'wheel'),
                                  content = isolate(tv$fimItems)
          )
        }
      }else if(isolate(uv$dom) == 'cog'){
        if(!is.na(isolate(rv$coggroup))){
          tv$funLevelsR[, 1:5] <- apply(tv$funLevelsR[, 1:5], 2,
                                        function(x) as.character(x + 1)
          )
          tlRowLength <- length(unlist(apply(tv$funLevelsR[, 1:5], 2,
                                             function(x) rle(x)$values
                                       )
          ))
          tlLevels <- unlist(apply(tv$funLevelsR[, 1:5], 2,
                                   function(x) rle(x)$values
          ))
          if(is.matrix(tlLevels)){
            tlLevels <- unlist(as.data.frame(tlLevels))
          }
          tlStarts <- rep(NA, tlRowLength)
          k <- 1
          for(j in 1:5){
            for(i in 2:nrow(isolate(tv$funLevelsR))){
              if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j] &&
                 (i - 1) == 1
              ){
                tlStarts[c(k, (k + 1))] <- as.character(
                  tv$funLevelsR$date[c((i - 1), i)]
                )
                k = k + 2
              }else if(tv$funLevelsR[i, j] != tv$funLevelsR[(i - 1), j]){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i])
                k <- k + 1
              }else if((i - 1) == 1){
                tlStarts[k] <- as.character(isolate(tv$funLevelsR$date)[i - 1])
                k <- k + 1
              }
            }
          }
          tlStarts <- as.Date(tlStarts)
          tlStarts <- paste(tlStarts, '00:00:00')
          tlStarts <- as.POSIXct(tlStarts, format = '%Y-%m-%d %H:%M:%S')
          tlEnds <- apply(tv$funLevelsR[, 1:5], 2, function(x) rle(x)$lengths)
          if(!is.matrix(tlEnds)){
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(apply(isolate(tv$funLevelsR)[, 1:5], 2,
                                  function(x) rle(x)$lengths
                            ), cumsum
              ))
            ]
          }else{
            tlEnds <- tv$funLevelsR$date[
              unlist(lapply(as.data.frame(apply(tv$funLevelsR[, 1:5], 2,
                                                function(x) rle(x)$lengths
                                          )), cumsum
              ))
            ]
          }
          tlEnds <- paste(tlEnds, '23:59:59')
          tlEnds <- as.POSIXct(tlEnds, format = '%Y-%m-%d %H:%M:%S')
          tlGroupLengths <- apply(tv$funLevels[, 1:5], 2,
                                  function(x) length(rle(x)$values)
          )
          tlComp <- rep('comp', tlGroupLengths[1])
          tlExp <- rep('exp', tlGroupLengths[2])
          tlSI <- rep('si', tlGroupLengths[3])
          tlPS <- rep('ps', tlGroupLengths[4])
          tlMem <- rep('mem', tlGroupLengths[5])
          tlGroup <- c(tlComp, tlExp, tlSI, tlPS, tlMem)
          tv$groups <- data.frame(id = c('comp', 'exp', 'si', 'ps', 'mem'),
                                  content = isolate(tv$fimItems)
          )
        }else{
          tlRowLength <- 5
          tlLevels <- c('', '', 'No SLP-Eval Yet', '', '')
          tlStarts <- rep(isolate(tv$admit), 5)
          tlEnds <- rep(isolate(tv$admit) + 1, 5)
          tlGroup <- c('comp', 'exp', 'si', 'ps', 'mem')
          
          tv$groups <- data.frame(id = c('comp', 'exp', 'si', 'ps', 'mem'),
                                  content = isolate(tv$fimItems)
          )
        }
      }
      
      tv$tlData <- data.frame(id = 1:tlRowLength,
                               content = tlLevels,
                               start = tlStarts,
                               end = tlEnds,
                               group = tlGroup
      )

      if(isolate(uv$dom) != 'cog' || !is.na(isolate(rv$coggroup))){
        tv$tlData$style <- ifelse(tv$tlData$content == '1',
                                  'background-color: #861f41;
                                   border-color: #861f41;
                                   height: 100%;',
                             ifelse(tv$tlData$content == '1 or 2',
                                    'background-color: #ba1d37;
                                     border-color: #ba1d37;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '1, 2, or 3',
                                    'background-color: #c24662;
                                     border-color: #c24662;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '2',
                                    'background-color: #ed1c2c;
                                     border-color: #ed1c2c;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '3',
                                    'background-color: #6d2077;
                                     border-color: #6d2077;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '4',
                                    'background-color: #ffd100;
                                     border-color: #ffd100;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '5',
                                    'background-color: #ffa168;
                                     border-color: #ffa168;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '6',
                                    'background-color: #fc8e13;
                                     border-color: #fc8e13;
                                     height: 100%;',
                             ifelse(tv$tlData$content == '6 or 7',
                                    'background-color: #f87d1a;
                                     border-color: #f87d1a;
                                     height: 100%;',
                                    'background-color: #f36b21;
                                     border-color: #f36b21;
                                     height: 100%;'
        )))))))))
      }else{
        tv$tlData$style <- 'background-color: #ffd100; border-color: #ffd100;'
      }
      
      tv$groups$style <- 'height: 40px;'

      output$timeline <- renderTimevis({
        timevis(data = isolate(tv$tlData), group = tv$groups, fit = T,
                options = list(stack = F, autoResize = T)
        )
      })
      
      output$patTL <- renderUI({
        div(
          div(class = 'ui three column grid',
              style = 'width: 100%; margin-bottom: 1em; padding-bottom: 0px;',
              div(class = 'row',
                  style = 'padding-top: 0px; padding-bottom: 0px;',
                  div(class = 'content',
                      style = 'width: 100%; height: 100%; font-size: 19px;',
                      id = 'tlContainer',
                      timevisOutput('timeline', width = '100%')
                  )
              )
          ),
          div(class = 'ui sixteen column grid shadowed',
              style = 'border-radius: .28571429rem;
                       margin-top: 0px; padding-bottom: 0px;',
              div(class = 'eight wide center aligned row',
                  style = 'padding-bottom: 0px;',
                  div(class = 'right aligned two wide column',
                      style = 'vertical-align: middle; padding-top: 1em;
                               padding-right: 0em; max-height: 5em;',
                      div(class = 'row',
                          HTML(
                            '<div style = "font-weight: bold; color: #1b1c1d;">
                               Expected LoS:
                             </div>'
                          )
                      )
                  ),
                  div(class = 'seven wide center aligned column',
                      style = 'margin: 0px; vertical-align: middle;
                               padding-top: 0.25em; max-height: 5em;',
                      selectInput('ExpLoS', label = NULL,
                                  c('3 - 18 days' = 2,
                                    '19 - 23 days' = 3,
                                    '24 - 30 days' = 4,
                                    '31 - 36 days' = 5,
                                    '36+ days' = 6
                                  ),
                                  selected = tv$losgroup
                      )
                  ),
                  div(class = 'six wide center aligned column',
                      style = 'padding-top: 0px;',
                      div(class = 'fluid orange ui button shadowed',
                          id = 'updateTL',
                          style = 'border-radius: .28571429rem;
                                   padding-top: 1em;',
                          'Update Timeline'
                      )
                  )
              )
          )
        )
      })
      
    }else{
      nullTL(axText = 'Date', message = 'No predictive model available')
    }
  }
  
  ## See nullGoal
  nullTL <- function(axText, message){
    nullX <- list(range = c(0, 50),
                title = 'Date',
                zeroline = F
    )
    nullY <- list(title = axText,
                range = c(-4, 4),
                zeroline = F
    )
    
    nullDat <- data.frame(x = 25,
                      y = 0
    )
    
    output$timeline <- renderPlotly({
      plot_ly(data = nullDat,
              x = ~x,
              y = ~y,
              type = 'scatter',
              mode = 'text',
              text = message,
              textfont = list(color = '#000000', size = 16)
      ) %>%
        layout(
          xaxis = nullX,
          yaxis = nullY,
          hoverlabel = list(font = list(size = 16))
        )
    })
    
    output$patTL <- renderUI({
      plotlyOutput('timeline')
    })
  }
  
  ## A helper function for renderDisplay. After renderDisplay resets reactive
  ## values, establishes some other reactive values, and ensures that a patient
  ## has been selected, createDisplay will direct the dashboard to the proper
  ## set of chart rendering functions. In that respect, it works a bit like a
  ## directory for the dashboard code. I probably should reverse the names of
  ## "createDisplay" and "renderDisplay," or just rename "renderDisplay."
  ### dom = a reactive value containing the user-selected AQ domain
  createDisplay <- function(dom){
    ## If the selected domain is self-care, run the appropriate functions for
    ## chart creation.
    if(dom == 'sc'){
      linePlotSC()
      goalPlotSC()
      sidebarSC()
    ## Otherwise, if it's mobility, run those functions.
    }else if(dom == 'mob'){
      linePlotMob()
      goalPlotMob()
      sidebarMob()
    ## Or, if the user selected cognition, run those functions. 
    }else if(dom == 'cog'){
      ## This part will render an empty chart with the reason that it's empty
      ## (if necessary).
      if(is.na(isolate(rv$coggroup))){
        ## A quick function for selecting the proper reason the TRC is empty
        nullMessage <- function(){
          return(ifelse(isolate(rv$row$cogGroup) == 'Other'
                        && !is.na(isolate(rv$row$cogGroup)),
                        'No Cog model available for this group', 'No SLP Eval'
          ))
        }
        ## Produces the empty plot with text
        nullProg(axText = 'AQ - Cog Scores', message = nullMessage())
      }else{
        linePlotCog()
      }
      goalPlotCog()
      sidebarCog()
    }
    ## Regardless of the chosen domain, load the sliders for the "FIM Update"
    ## section.
    scEdit()
    mobEdit()
    cogEdit()
  }
  
  ## As alluded to in the description of the createDisplay function, this
  ## function runs as soon as a patient is selected and nullifies reactive
  ## values so that there's no "leaking" between patients.
  renderDisplay <- function(){
    ## Nullify all the things we don't want to carry over from patient to
    ## patient.
    rv$toPlot <- NULL
    rv$fimPlot <- NULL
    predDates <- NULL
    rv$predPlot <- NULL
    rv$predPlotFull <- NULL
    rv$fimPlot <- NULL
    rv$pal <- NULL
    rv$xAx <- NULL
    rv$yAx <- NULL
    fimScores <- NULL
    fimActual <- NULL
    fimGoals <- NULL
    fimPred <- NULL
    rv$fimPlot <- NULL
    # rv$newGoals <- NULL
    gv$scgroup <- NULL
    gv$mobgroup <- NULL
    gv$coggroup <- NULL
    # gv$eat <- NA
    # gv$groom <- NA
    # gv$bath <- NA
    # gv$ubDress <- NA
    # gv$lbDress <- NA
    # gv$toilet <- NA
    # gv$bcTrans <- NA
    # gv$tsTrans <- NA
    # gv$tTrans <- NA
    # gv$locWalk <- NA
    # gv$locWheel <- NA
    # gv$locStairs <- NA
    # gv$comp <- NA
    # gv$exp <- NA
    # gv$si <- NA
    # gv$ps <- NA
    # gv$mem <- NA
    tv$fimPar <- NULL
    tv$tlPreds <- NULL
    tv$fimItems <- NULL
    tv$funLevels <- NULL
    tv$funLevelsR <- NULL
    tv$tlData <- NULL
    
    ## If the user has selected a patient, run createDisplay with the active
    ## AQ domain. If they haven't selected a patient, show a passive-aggressive
    ## message.
    if(!is.null(isolate(rv$row))){
      createDisplay(dom = uv$dom)
    }else{
      showNotification("Please select a patient", duration = NULL)
    }
  }
  
  ## Actually operates a bit like createDisplay in the "directory" regard.
  ## Mostly, though, it is a helper function for resetITC that replots the
  ## original TRC when the reset button is pressed (usually after the user
  ## makes edits to patient goals, group, or LoS).
  progPlotHandler <- function(){
    if(uv$dom == 'sc'){
      if(!is.null(rv$scSco)){
        linePlotSC()
      }else{
        nullProg(axText = 'AQ - SC Scores',
                 message = 'No AQ measures found for this patient'
        )
      }
    }else if(uv$dom == 'mob'){
      if(!is.null(rv$mobSco)){
        linePlotMob()
      }else{
        nullProg(axText = 'AQ - Mob Scores',
                 message = 'No AQ measures found for this patient'
        )
      }
    }else if(uv$dom == 'cog'){
      if(!is.null(rv$cogSco)){
        linePlotCog()
      }else{
        nullProg(axText = 'AQ - Cog Scores',
                 message = 'No AQ measures found for this patient'
        )
      }
    }
  }

  ## Deprecated. It was used to reset changes to the FIM Goals barplot, but
  ## those options have since been removed.
  goalPlotHandler <- function(){
    if(uv$dom == 'sc'){
      goalPlotSC()
    }else if(uv$dom == 'mob'){
      goalPlotMob()
    }else if(uv$dom == 'cog'){
      goalPlotCog()
    }
  }
  
  ## An event handler for when the user makes changes to the patient's group,
  ## goals, or LoS. Updates the TRC, sidebar, and timeline as all of those will
  ## require changes if the patient's group is changed.
  updateHandler <- function(){
    gv$losgroup <- input$losGroup
    tv$losgroup <- input$losGroup
    if(isolate(uv$dom) == 'sc'){
      initTC_sc(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
                goalGroup = input$balLevel, losGroup = input$losGroup,
                xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
      )
      goalPlotSC()
      sidebarSC()
    }else if(isolate(uv$dom) == 'mob'){
      initTC_mob(toPlot = rv$toPlot, predPlot = rv$predPlot,
                 fgLine = rv$fgLine, goalGroup = input$canWalk,
                 losGroup = input$losGroup, xAx = rv$xAx, yAx = rv$yAx,
                 pal = rv$pal
      )
      goalPlotMob_update()
      sidebarMob()
      sidebarMob()
    }else{
      initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot,
                 fgLine = rv$fgLine, goalGroup = input$cogDiag,
                 losGroup = input$losGroup, xAx = rv$xAx, yAx = rv$yAx,
                 pal = rv$pal
      )
      goalPlotCog()
      sidebarCog()
    }
  }
  
  ## This function is mostly deprecated, but still performs the important task
  ## of updating the LoS selectInputs for the timeline and TRC. Otherwise, it
  ## merely refreshes the timeline with the proper LoS group.
  updateHandler2 <- function(){
    ## Read the inputs for the TRC and timeline LoS group selectInputs, then
    ## updates those to display the proper values after the relevant renderUI
    ## functions perform their duty.
    gv$losgroup <- input$ExpLoS
    tv$losgroup <- input$ExpLoS
    updateSelectInput(session,
      'losGroup', 'Expected LoS',
       c('3 - 18 days' = 2,
         '19 - 23 days' = 3,
         '24 - 30 days' = 4,
         '31 - 36 days' = 5,
         '36+ days' = 6
       ),
       selected = max(gv$losgroup, 2)
    )
    ## Runs the proper TRC and timeline functions, depending on selected AQ
    ## domain.
    if(isolate(uv$dom) == 'sc'){
      initTC_sc(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
                goalGroup = input$balLevel, losGroup = gv$losgroup,
                xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
      )
    }else if(isolate(uv$dom) == 'mob'){
      initTC_mob(toPlot = rv$toPlot, predPlot = rv$predPlot,
                 fgLine = rv$fgLine, goalGroup = input$canWalk,
                 losGroup = gv$losgroup, xAx = rv$xAx, yAx = rv$yAx,
                 pal = rv$pal
      )
    }else{
      if(tv$nullCogTL == 0){
        initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot,
                   fgLine = rv$fgLine, goalGroup = input$cogDiag,
                   losGroup = gv$losgroup, xAx = rv$xAx, yAx = rv$yAx,
                   pal = rv$pal
        )
      }
    }
  }
  
  ## An update handler for the "Update FIM" button, which is useful for cases
  ## when the FIM data pulled from the EDW is incorrect (a problem that
  ## admittedly will eventually go away once all process and EDW issues are
  ## solved).
  updateHandler3 <- function(){
    ## If the selected domain is self-care...
    if(uv$dom == 'sc'){
      ## If today's date is in the raw FIM-SC data.frame, overwrite those
      ## values with the new values the user has specified.
      if(Sys.Date() %in% rv$fimSCO$assessmentDate[which(
                                                    rv$fimSCO$FIN == rv$fin
                                                  )
                         ]
      ){
        rv$fimSCO[intersect(
                    which(rv$fimSCO$assessmentDate == Sys.Date()),
                    which(rv$fimSCO$FIN == rv$fin)), 3:8
        ] <- rv$datSC - 1
      ## Otherwise, if they don't have any FIM data for the current day, create
      ## a new row in the FIM-SC data frame and record the user-specified FIM
      ## data there.
      }else{
        newRow <- data.frame(MRN = isolate(rv$row[2]),
                             FIN = isolate(rv$row[1]),
                             eating = isolate(rv$datSC[1]) - 1,
                             grooming = isolate(rv$datSC[2]) - 1,
                             bathing = isolate(rv$datSC[3]) - 1,
                             dressingUpper = isolate(rv$datSC[4]) - 1,
                             dressingLower = isolate(rv$datSC[5]) - 1,
                             toileting = isolate(rv$datSC[6]) - 1,
                             assessmentDate = Sys.Date(),
                             FINAD = pasteFun(isolate(rv$row[1]), Sys.Date())
        )
        rv$fimSCO <- rbind(isolate(rv$fimSCO), newRow)
        rv$fimSCO <- rv$fimSCO[order(rv$fimSCO$FIN,
                                     rv$fimSCO$assessmentDate
                               )
        , ]
      }
      ## Now that the specified FIM-SC data has been established, perform the
      ## proper recoding for IRT scoring.
      if(dim(isolate(rv$scData))[1] > 0){
        ## If the patient has some other assessment date, put the recoded data
        ## in the proper reactive value for IRT scoring.
        if(Sys.Date() %in% isolate(rv$scData$assessmentDate)){
          newRow2 <- isolate(rv$datSC) - 1
          newRow2$grooming <- car::recode(newRow2$grooming,
                                          "0=0;1=0;2=0;3=1;4=2;5=3;6=4;"
          )
          newRow2$bathing <- car::recode(newRow2$bathing,
                                         "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
          )
          newRow2$dressingLower <- car::recode(newRow2$dressingLower,
                                               "0=0;1=0;2=1;3=2;4=3;5=4;6=5;"
          )
          newRow2$toileting <- car::recode(newRow2$toileting,
                                           "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
          )
          rv$scData[which(
                      rv$scData$assessmentDate == Sys.Date()
                    )
          , 51:56] <- newRow2
        ## Otherwise, if they don't, just add a new row in that data.frame.
        }else{
          newRow2 <- tail(isolate(rv$scData), 1)
          newRow2$assessmentDate <- Sys.Date()
          newRow2$FINAD <- pasteFun(isolate(rv$row[1]), Sys.Date())
          newRow2[, 5:50] <- NA
          newRow2[, 51:56] <- isolate(rv$datSC) - 1
          newRow2$grooming <- car::recode(newRow2$grooming,
                                          "0=0;1=0;2=0;3=1;4=2;5=3;6=4;"
          )
          newRow2$bathing <- car::recode(newRow2$bathing,
                                         "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
          )
          newRow2$dressingLower <- car::recode(newRow2$dressingLower,
                                               "0=0;1=0;2=1;3=2;4=3;5=4;6=5;"
          )
          newRow2$toileting <- car::recode(newRow2$toileting,
                                           "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
          )
          isolate(rv$scData <- rbind(rv$scData, newRow2))
        }
      ## If the patient has no self-care data at all, create the rv$scData
      ## reactive value that would have already been established had the
      ## patient had self-care data.
      }else{
        newRow2 <- as.data.frame(c(isolate(rv$row[2]),
                                   isolate(rv$row[1]),
                                   Sys.Date(),
                                   pasteFun(isolate(rv$row[1]), Sys.Date()),
                                   rep(NA, 46),
                                   unlist(isolate(rv$datSC)) - 1
                                 )
        )
        colnames(newRow2) <- colnames(sc)
        newRow2$grooming <- car::recode(newRow2$grooming,
                                        "0=0;1=0;2=0;3=1;4=2;5=3;6=4;"
        )
        newRow2$bathing <- car::recode(newRow2$bathing,
                                       "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
        )
        newRow2$dressingLower <- car::recode(newRow2$dressingLower,
                                             "0=0;1=0;2=1;3=2;4=3;5=4;6=5;"
        )
        newRow2$toileting <- car::recode(newRow2$toileting,
                                         "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
        )
        newRow2$assessmentDate <- as.Date(newRow2$assessmentDate,
                                          format = '%Y-%m-%d'
        )
        rv$scData <- newRow2
      }
      ## With the rv$scData reactive value now either updated or created, score
      ## it.
      if(dim(rv$scData)[1] > 0 &&
         any(apply(rv$scData[, 5:56], c(1, 2),
                   function(x) !is.na(x) && x < 10
             ))
      ){
        rv$scSco <- scoFunSCFIM(data = rv$scData, group = rv$scgroup)
      }else{
        rv$scSco <- NULL
      }
      ## Now rerun all the plot-making functions with the updated FIM-SC data.
      initTC_sc()
      goalPlotSC()
      sidebarSC()
      scEdit()
    }
    ## Otherwise, if the domain is mobility...
    ## NB: this is all more or less the same as the process for self-care, so
    ##     there isn't any mark-up below
    if(uv$dom == 'mob'){
      if(Sys.Date() %in% rv$fimMobO$assessmentDate[which(
                                                     rv$fimMobO$FIN == rv$fin
                                                   )
                         ]
      ){
        rv$fimMobO[intersect(which(rv$fimMobO$assessmentDate == Sys.Date()),
                             which(rv$fimMobO$FIN == rv$fin)
                   )
        , 3:8] <- rv$datMob - 1
      }else{
        newRow <- data.frame(MRN = isolate(rv$row[2]),
                             FIN = isolate(rv$row[1]),
                             bedChairTransfer = isolate(rv$datMob[1]) - 1,
                             tubShowerTransfer = isolate(rv$datMob[2]) - 1,
                             toiletTransfer = isolate(rv$datMob[3]) - 1,
                             locomotionWalk = isolate(rv$datMob[4]) - 1,
                             locomotionWheelchair = isolate(rv$datMob[5]) - 1,
                             locomotionStairs = isolate(rv$datMob[6]) - 1,
                             assessmentDate = Sys.Date()
        )
        rv$fimMobO <- rbind(isolate(rv$fimMobO), newRow)
        rv$fimMobO <- rv$fimMobO[order(rv$fimMobO$FIN,
                                       rv$fimMobO$assessmentDate
                                 )
        , ]
      }
      if(dim(isolate(rv$mobData))[1] > 0){
        if(Sys.Date() %in% isolate(rv$mobData$assessmentDate)){
          newRow2 <- isolate(rv$datMob) - 1
          newRow2$tubShowerTransfer <- car::recode(
            newRow2$tubShowerTransfer, "0=0;1=1;2=2;3=3;4=4;5=5;6=5"
          )
          rv$mobData[which(
                       rv$mobData$assessmentDate == Sys.Date()
                     )
          , 30:35] <- newRow2
        }else{
          newRow2 <- tail(isolate(rv$mobData), 1)
          newRow2$assessmentDate <- Sys.Date()
          newRow2$FINAD <- pasteFun(isolate(rv$row[1]), Sys.Date())
          newRow2[, 5:29] <- NA
          newRow2[, 30:35] <- isolate(rv$datMob) - 1
          newRow2$tubShowerTransfer <- car::recode(
            newRow2$tubShowerTransfer, "0=0;1=1;2=2;3=3;4=4;5=5;6=5"
          )
          isolate(rv$mobData <- rbind(rv$mobData, newRow2))
        }
      }else{
        newRow2 <- as.data.frame(c(isolate(rv$row[2]),
                                   isolate(rv$row[1]),
                                   Sys.Date(),
                                   pasteFun(isolate(rv$row[1]), Sys.Date()),
                                   rep(NA, 25),
                                   unlist(isolate(rv$datMob)) - 1
                                 )
        )
        colnames(newRow2) <- colnames(mob)
        newRow2$tubShowerTransfer <- car::recode(
          newRow2$tubShowerTransfer, "0=0;1=1;2=2;3=3;4=4;5=5;6=5"
        )
        newRow2$assessmentDate <- as.Date(newRow2$assessmentDate,
                                          format = '%Y-%m-%d'
        )
        rv$mobData <- newRow2
      }
      if(dim(rv$mobData)[1] > 0 && any(apply(rv$mobData[, 5:35], c(1, 2),
                                             function(x) !is.na(x) && x < 10
                                       ))
      ){
        rv$mobSco <- scoFunMobFIM(data = rv$mobData, group = rv$mobgroup)
      }else{
        rv$mobSco <- NULL
      }
      initTC_mob()
      goalPlotMob()
      sidebarMob()
      mobEdit()
    }
    ## As you've probably ascertained at this point, the stuff down here
    ## happens if the selected domain is cognition.
    if(uv$dom == 'cog'){
      if(Sys.Date() %in% rv$fimCogO$assessmentDate[which(
                                                     rv$fimCogO$FIN == rv$fin
                                                   )
                         ]
      ){
        rv$fimCogO[intersect(which(rv$fimCogO$assessmentDate == Sys.Date()),
                             which(rv$fimCogO$FIN == rv$fin))
        , 3:7] <- rv$datCog - 1
      }else{
        newRow <- data.frame(MRN = isolate(rv$row[2]),
                             FIN = isolate(rv$row[1]),
                             comprehension = isolate(rv$datCog[1]) - 1,
                             expression = isolate(rv$datCog[2]) - 1,
                             socialInteraction = isolate(rv$datCog[3]) - 1,
                             problemSolving = isolate(rv$datCog[4]) - 1,
                             memory = isolate(rv$datCog[5]) - 1,
                             assessmentDate = Sys.Date(),
                             FINAD = pasteFun(isolate(rv$row[1]), Sys.Date())
        )
        rv$fimCogO <- rbind(isolate(rv$fimCogO), newRow)
        rv$fimCogO <- rv$fimCogO[order(
                                   rv$fimCogO$FIN,
                                   rv$fimCogO$assessmentDate
                                 )
        , ]
      }
      if(dim(isolate(rv$cogData))[1] > 0){
        if(Sys.Date() %in% isolate(rv$cogData$assessmentDate)){
          newRow2 <- isolate(rv$datCog) - 1
          rv$cogData[which(
                       rv$cogData$assessmentDate == Sys.Date()
                     )
          , 39:43] <- newRow2
        }else{
          newRow2 <- tail(isolate(rv$cogData), 1)
          newRow2$assessmentDate <- Sys.Date()
          newRow2$FINAD <- pasteFun(isolate(rv$row[1]), Sys.Date())
          newRow2[, 5:38] <- NA
          newRow2[, 39:43] <- isolate(rv$datCog) - 1
          isolate(rv$cogData <- rbind(rv$cogData, newRow2))
        }
      }else{
        newRow2 <- as.data.frame(c(isolate(rv$row[2]),
                                   isolate(rv$row[1]),
                                   Sys.Date(),
                                   pasteFun(isolate(rv$row[1]), Sys.Date()),
                                   rep(NA, 34),
                                   unlist(isolate(rv$datCog)) - 1
                                 )
        )
        colnames(newRow2) <- colnames(cog)
        newRow2$assessmentDate <- as.Date(newRow2$assessmentDate,
                                          format = '%Y-%m-%d'
        )
        rv$cogData <- newRow2
      }
      if(dim(rv$cogData)[1] > 0 && any(apply(rv$cogData[, 5:43], c(1, 2),
                                             function(x) !is.na(x) && x < 10
                                       ))
      ){
        rv$cogSco <- scoFunCogFIM(data = rv$cogData, group = rv$coggroup)
      }else{
        rv$cogSco <- NULL
      }
      initTC_cog()
      goalPlotCog()
      sidebarCog()
      cogEdit()
    }
  }

  ## The first function run when the reset button is pressed. It runs resetITC
  ## (to reset the TRC), then also rerenders the timeline and sidebar.
  resetHandler <- function(){
    resetITC()
    if(isolate(uv$dom == 'sc')){
      sidebarSC()
    }else if(isolate(uv$dom == 'mob')){
      sidebarMob()
    }else{
      sidebarCog()
    }
  }

  ## This still works but requires a little bit of updating on the ui.R side of
  ## the dashboard. This runs the Help walkthrough when the Help button is
  ## clicked.
  intro <- function(){
    introjs(session,
            options = list('nextLabel' = 'Next',
                           'prevLabel' = 'Previous',
                           'skipLabel' = 'Exit',
                           'doneLabel' = 'Got it!'
                      )
    )
  }
  
  ## Deprecated. Used to "turn off" balance on the self-care TRC. Sometimes
  ## caused changes in scores that made sense psychometrically/mathematically,
  ## but were difficult to explain intuitively.
  balsc_switch <- function(){
    if(uv$balsc_switch == 1){
      uv$balsc_switch <- 0
    }else{
      uv$balsc_switch <- 1
    }
    initTC_sc(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
              goalGroup = input$balLevel, losGroup = input$losGroup,
              xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarSC()
  }
  
  ## Deprecated. See above.
  uef_switch <- function(){
    if(uv$uef_switch == 1){
      uv$uef_switch <- 0
    }else{
      uv$uef_switch <- 1
    }
    initTC_sc(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
              goalGroup = input$balLevel, losGroup = input$losGroup,
              xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarSC()
  }
  
  ## Still in use; drops the swallowing assessment area from the self-care TRC,
  ## which is replotted. Also reestimates the percentages in the sidebar.
  swl_switch <- function(){
    if(uv$swl_switch == 1){
      uv$swl_switch <- 0
    }else{
      uv$swl_switch <- 1
    }
    initTC_sc(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
              goalGroup = input$balLevel, losGroup = input$losGroup,
              xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarSC()
  }
  
  ## Deprecated. See other deprecated switches.
  balmob_switch <- function(){
    if(uv$balmob_switch == 1){
      uv$balmob_switch <- 0
    }else{
      uv$balmob_switch <- 1
    }
    initTC_mob(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$canWalk, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarMob()
  }
  
  ## Like swl_switch, this one is also used for removing an assessment area
  ## from the TRC, though this is for wheelchair skills in the mobility
  ## domain.
  wc_switch <- function(){
    if(uv$wc_switch == 1){
      uv$wc_switch <- 0
    }else{
      uv$wc_switch <- 1
    }
    initTC_mob(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$canWalk, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarMob()
  }
  
  ## Deprecated. See other deprecated switches.
  xfer_switch <- function(){
    if(uv$xfer_switch == 1){
      uv$xfer_switch <- 0
    }else{
      uv$xfer_switch <- 1
    }
    initTC_mob(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine, goalGroup = input$canWalk,
              losGroup = input$losGroup, xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarMob()
  }
  
  ## Deprecated. See other deprecated switches.
  cbp_switch <- function(){
    if(uv$cbp_switch == 1){
      uv$cbp_switch <- 0
    }else{
      uv$cbp_switch <- 1
    }
    initTC_mob(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$canWalk, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarMob()
  }
  
  ## Deprecated. See other deprecated switches.
  com_switch <- function(){
    if(uv$com_switch == 1){
      uv$com_switch <- 0
    }else{
      uv$com_switch <- 1
    }
    initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$cogDiag, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarCog()
  }
  
  ## Deprecated. See other deprecated switches.
  wcom_switch <- function(){
    if(uv$wcom_switch == 1){
      uv$wcom_switch <- 0
    }else{
      uv$wcom_switch <- 1
    }
    initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$cogDiag, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarCog()
  }
  
  ## Deprecated. See other deprecated switches.
  comp_switch <- function(){
    if(uv$comp_switch == 1){
      uv$comp_switch <- 0
    }else{
      uv$comp_switch <- 1
    }
    initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$cogDiag, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarCog()
  }
  
  ## Deprecated. See other deprecated switches.
  spe_switch <- function(){
    if(uv$spe_switch == 1){
      uv$spe_switch <- 0
    }else{
      uv$spe_switch <- 1
    }
    initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$cogDiag, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarCog()
  }
  
  ## Deprecated. See other deprecated switches.
  mem_switch <- function(){
    if(uv$mem_switch == 1){
      uv$mem_switch <- 0
    }else{
      uv$mem_switch <- 1
    }
    initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$cogDiag, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarCog()
  }
  
  ## Deprecated. See other deprecated switches.
  agi_switch <- function(){
    if(uv$agi_switch == 1){
      uv$agi_switch <- 0
    }else{
      uv$agi_switch <- 1
    }
    initTC_cog(toPlot = rv$toPlot, predPlot = rv$predPlot, fgLine = rv$fgLine,
               goalGroup = input$cogDiag, losGroup = input$losGroup,
               xAx = rv$xAx, yAx = rv$yAx, pal = rv$pal
    )
    sidebarCog()
  }
  
  }   # R functions
  
  {
  col <- c('#888b8d', '#861f41', '#ed1c2c', '#6d2077', '#ffd100', '#ffa168',
           '#fc8e13', '#f36b21'
  )
  names(col) <- c('gray', 'maroon', 'red', 'purple', 'yellow', 'lt. orange',
                  'med. orange', 'orange'
  )
  }   # Palette
  
  {
  ## Pulls in the the driver from the working directory.
  # drv <- JDBC(driverClass = 'org.postgresql.Driver',
  #             classPath = 'postgresql-9.4.1209.jre6.jar'
  # )
  ## Open connection to the EDW.
  awsCon <- DBI::dbConnect(RPostgres::Postgres(),
                           host = host,
                           port = port, dbname = dbname,
                           user = user, password = pwd
  )
  
  ## Queries for the IRT model parameters.
  siBalPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.sitbalparsfim;')
  stBalPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.standbalparsfim;')
  waBalPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.walkbalparsfim;')
  wheelPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.wheelparsfim;')
  bothPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.bothparsfim;')
  walkPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.walkparsfim;')
  aphPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.aphparsfim;')
  ccdPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.ccdparsfim;')
  biPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.biparsfim;')
  rhdPar <- dbGetQuery(awsCon, 'select * from sandboxomsa.rhdparsfim;')
  spePar <- dbGetQuery(awsCon, 'select * from sandboxomsa.speparsfim;')

  ## Queries for predictive models
  scPreds <- dbGetQuery(awsCon, 'select * from sandboxomsa.scpreds_fim;')
  mobPreds <- dbGetQuery(awsCon, 'select * from sandboxomsa.mobpreds_fim;')
  cogPreds <- dbGetQuery(awsCon, 'select * from sandboxomsa.cogpreds_fim;')
  colnames(scPreds) <- c('time', 'msg', 'cmg', 'scgroup', 'longstay',
                         'yhat6'
  )
  colnames(mobPreds) <- c('time', 'msg', 'cmg', 'mobgroup', 'longstay',
                          'yhat6'
  )
  colnames(cogPreds) <- c('time', 'msg', 'cmg', 'coggroup', 'longstay',
                          'yhat6'
  )
  
  ## Close connection to the EDW.
  dbDisconnect(awsCon)
  
  ## Add column names to the data.frames containing IRT model parameters.
  colnames(siBalPar) <- c('itemNum', 'itemName', paste('a', 1:5, sep = ''),
                          paste('d', 1:6, sep = '')
  )
  colnames(stBalPar) <- c('itemNum', 'itemName', paste('a', 1:5, sep = ''),
                          paste('d', 1:6, sep = '')
  )
  colnames(waBalPar) <- c('itemNum', 'itemName', paste('a', 1:5, sep = ''),
                          paste('d', 1:6, sep = '')
  )
  colnames(wheelPar) <- c('itemNum', 'itemName', paste('a', 1:5, sep = ''),
                          paste('d', 1:6, sep = '')
  )
  colnames(bothPar) <- c('itemNum', 'itemName', paste('a', 1:6, sep = ''),
                         paste('d', 1:6, sep = '')
  )
  colnames(walkPar) <- c('itemNum', 'itemName', paste('a', 1:6, sep = ''),
                         paste('d', 1:6, sep = '')
  )
  colnames(aphPar) <- c('itemNum', 'itemName', paste('a', 1:7, sep = ''),
                        paste('d', 1:6, sep = '')
  )
  colnames(ccdPar) <- c('itemNum', 'itemName', paste('a', 1:4, sep = ''),
                        paste('d', 1:6, sep = '')
  )
  colnames(biPar) <- c('itemNum', 'itemName', paste('a', 1:9, sep = ''),
                       paste('d', 1:6, sep = '')
  )
  colnames(rhdPar) <- c('itemNum', 'itemName', paste('a', 1:4, sep = ''),
                        paste('d', 1:6, sep = '')
  )
  colnames(spePar) <- c('itemNum', 'itemName', paste('a', 1:10, sep = ''),
                        paste('d', 1:6, sep = '')
  )
  
  ## Order IRT parameters the same as what the AQ data will be.
  siBalPar <- siBalPar[order(siBalPar$itemNum), ]
  stBalPar <- stBalPar[order(stBalPar$itemNum), ]
  waBalPar <- waBalPar[order(waBalPar$itemNum), ]
  wheelPar <- wheelPar[order(wheelPar$itemNum), ]
  bothPar <- bothPar[order(bothPar$itemNum), ]
  walkPar <- walkPar[order(walkPar$itemNum), ]
  aphPar <- aphPar[order(aphPar$itemNum), ]
  ccdPar <- ccdPar[order(ccdPar$itemNum), ]
  biPar <- biPar[order(biPar$itemNum), ]
  rhdPar <- rhdPar[order(rhdPar$itemNum), ]
  spePar <- spePar[order(spePar$itemNum), ]
  
  ## Simply replaces 0.00 slopes with missing values
  siBalPar[, 3:7] <- apply(siBalPar[, 3:7], c(1, 2),
                           function(x){
                             ifelse(x == 0, NA, x)
                           }
  )
  stBalPar[, 3:7] <- apply(stBalPar[, 3:7], c(1, 2),
                           function(x){
                             ifelse(x == 0, NA, x)
                           }
  )
  waBalPar[, 3:7] <- apply(waBalPar[, 3:7], c(1, 2),
                           function(x){
                             ifelse(x == 0, NA, x)
                           }
  )
  wheelPar[, 3:13] <- apply(wheelPar[, 3:13], c(1, 2),
                              function(x){
                                ifelse(x == 0, NA, x)
                              }
  )
  bothPar[, 3:14] <- apply(bothPar[, 3:14], c(1, 2),
                             function(x){
                               ifelse(x == 0, NA, x)
                             }
  )
  walkPar[, 3:14] <- apply(walkPar[, 3:14], c(1, 2),
                             function(x){
                               ifelse(x == 0, NA, x)
                             }
  )
  aphPar[, 3:9] <- apply(aphPar[, 3:9], c(1, 2),
                           function(x){
                             ifelse(x == 0, NA, x)
                           }
  )
  ccdPar[, 3:6] <- apply(ccdPar[, 3:6], c(1, 2),
                           function(x){
                             ifelse(x == 0, NA, x)
                           }
  )
  biPar[, 3:11] <- apply(biPar[, 3:11], c(1, 2),
                           function(x){
                             ifelse(x == 0, NA, x)
                           }
  )
  rhdPar[, 3:6] <- apply(rhdPar[, 3:6], c(1, 2),
                           function(x){
                             ifelse(x == 0, NA, x)
                           }
  )
  spePar[, 3:12] <- apply(spePar[, 3:12], c(1, 2),
                            function(x){
                              ifelse(x == 0, NA, x)
                            }
  )
  
  ## Converts IRT intercepts into difficulty parameters.
  siBalBs <- d2b(siBalPar[, 8:13], siBalPar[, 3:7])
  stBalBs <- d2b(stBalPar[, 8:13], stBalPar[, 3:7])
  waBalBs <- d2b(waBalPar[, 8:13], waBalPar[, 3:7])
  wheelBs <- d2b(wheelPar[, 8:13], wheelPar[, 3:7])
  bothBs <- d2b(bothPar[, 9:14], bothPar[, 3:8])
  walkBs <- d2b(walkPar[, 9:14], walkPar[, 3:8])
  aphBs <- d2b(aphPar[, 10:15], aphPar[, 3:9])
  ccdBs <- d2b(ccdPar[, 7:12], ccdPar[, 3:6])
  biBs <- d2b(biPar[, 12:17], biPar[, 3:11])
  rhdBs <- d2b(rhdPar[, 7:12], rhdPar[, 3:6])
  speBs <- d2b(spePar[, 13:18], spePar[, 3:12])
  
  ## These are the IRT latent trait means for each assessment group within each
  ## domain.
  siBalMeans <- c(-0.13, 1.77, 2.43, -1.42, 0.00)
  stBalMeans <- c(0.78, 0.33, 1.39, -0.03, 0.00)
  waBalMeans <- c(2.05, 0.84, 1.37, 1.51, 0.00)
  wheelMeans <- c(-1.40, -1.81, 1.27, -0.37, 0.20)
  bothMeans <- c(-0.48, -0.52, 0.37, 0.00, 0.00, 0.00)
  walkMeans <- c(0.63, 0.63, -0.45, 0.07, 0.00, 0.00)
  aphMeans <- c(-0.49, 0.00, 0.00, 0.00, 0.12, 0.07, 0.01)
  ccdMeans <- c(0.64, 0.00, 0.08, 0.38)
  biMeans <- c(-0.23, 0.00, 0.20, 0.71, 0.00, 0.00, 0.00, 1.18, 0.00)
  rhdMeans <- c(0.28, 0.00, 0.00, 0.68)
  speMeans <- c(2.06, 0.00, -0.80, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00, 0.00)

  ## IRT latent trait variances
  scLTCovSiBal <- diag(5) * c(1.00, 9.63, 2.30, 0.76, 0.63)
  scLTCovStBal <- diag(5) * c(1.00, 3.01, 1.77, 0.77, 0.38)
  scLTCovWaBal <- diag(5) * c(1.00, 3.19, 2.18, 0.97, 0.62)
  mobLTCovWheel <- diag(5) * c(1.00, 2.05, 2.91, 0.42, 1.23)
  mobLTCovBoth <- diag(6) * c(1.00, 1.28, 0.87, 0.19, 1.00, 2.20)
  mobLTCovWalk <- diag(6) * c(1.00, 1.22, 1.05, 0.28, 1.00, 1.00)
  cogLTCovAph <- diag(7) * c(1.00, 0.61, 1.00, 1.00, 0.54, 0.82, 0.91)
  cogLTCovCCD <- diag(4) * c(1.00, 1.06, 1.07, 0.64)
  cogLTCovBI <- diag(9) * c(1.00, 0.86, 1.36, 0.50, 1.00, 1.00, 1.00, 3.13,
                            0.97
  )
  cogLTCovRHD <- diag(4) * c(1.00, 0.54, 1.00, 0.62)
  cogLTCovSpe <- diag(10) * c(1.00, 1.67, 1.13, 1.00, 1.00, 1.00, 1.00, 1.00,
                              1.00, 0.99
  )
  
  ## Build the IRT models for scoring later
  scModSiBal <- generate.mirt_object(siBalPar[, 3:13], itemtype = 'graded',
                                     latent_means = siBalMeans,
                                     latent_covariance = scLTCovSiBal
  )
  scModStBal <- generate.mirt_object(stBalPar[, 3:13], itemtype = 'graded',
                                     latent_means = stBalMeans,
                                     latent_covariance = scLTCovStBal
  )
  scModWaBal <- generate.mirt_object(waBalPar[, 3:13], itemtype = 'graded',
                                     latent_means = waBalMeans,
                                     latent_covariance = scLTCovWaBal
  )
  mobModWheel <- generate.mirt_object(wheelPar[, 3:13], itemtype = 'graded',
                                      latent_means = wheelMeans,
                                      latent_covariance = mobLTCovWheel
  )
  mobModBoth <- generate.mirt_object(bothPar[, 3:14], itemtype = 'graded',
                                     latent_means = bothMeans,
                                     latent_covariance = mobLTCovBoth
  )
  mobModWalk <- generate.mirt_object(walkPar[, 3:14], itemtype = 'graded',
                                     latent_means = walkMeans,
                                     latent_covariance = mobLTCovWalk
  )
  cogModAph <- generate.mirt_object(aphPar[, 3:15], itemtype = 'graded',
                                    latent_means = aphMeans,
                                    latent_covariance = cogLTCovAph
  )
  cogModCCD <- generate.mirt_object(ccdPar[, 3:12], itemtype = 'graded',
                                    latent_means = ccdMeans,
                                    latent_covariance = cogLTCovCCD
  )
  cogModBI <- generate.mirt_object(biPar[, 3:17], itemtype = 'graded',
                                   latent_means = biMeans,
                                   latent_covariance = cogLTCovBI
  )
  cogModRHD <- generate.mirt_object(rhdPar[,3:12], itemtype = 'graded',
                                    latent_means = rhdMeans,
                                    latent_covariance = cogLTCovRHD
  )
  ## Because the mirt package only allows 9 factors for some stupid reason,
  ## we'll drop unnecessary ones that are artefacts of the multigroup design...
  spePar <- spePar[, -(6:11)]
  colnames(spePar)[3:6] <- paste('a', 1:4, sep = '')
  speMeans <- speMeans[-(4:9)]
  cogLTCovSpe <- cogLTCovSpe[-(4:9), -(4:9)]
  cogModSpe <- generate.mirt_object(spePar[, 3:12], itemtype = 'graded',
                                    latent_means = speMeans,
                                    latent_covariance = cogLTCovSpe
  )
  
  {
  ## Creates a hypothetical "all minimum" dataset for each self-care group.
  minDatSiBalG <- matrix(0, nrow = 1, ncol = nrow(siBalPar))
  minDatStBalG <- matrix(0, nrow = 1, ncol = nrow(stBalPar))
  minDatWaBalG <- matrix(0, nrow = 1, ncol = nrow(waBalPar))
  ## Scores those minimum datasets and pulls out the self-care score.
  minScoSiBalG <- as.data.frame(
                    fscores(scModSiBal, response.pattern = minDatSiBalG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = siBalMeans, cov = scLTCovSiBal
                    )
  )$F1
  minScoStBalG <- as.data.frame(
                    fscores(scModStBal, response.pattern = minDatStBalG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = stBalMeans, cov = scLTCovStBal
                    )
  )$F1
  minScoWaBalG <- as.data.frame(
                    fscores(scModWaBal, response.pattern = minDatWaBalG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = waBalMeans, cov = scLTCovWaBal
                    )
  )$F1
  ## Creates a hypothetical "all maximum" data set for each self-care group.
  maxDatSiBalG <- matrix(as.numeric(apply(siBalBs, 1,
                                          function(x) sum(!is.na(x))
                                    )), nrow = 1, ncol = nrow(siBalPar)
  )
  maxDatStBalG <- matrix(as.numeric(apply(stBalBs, 1,
                                          function(x) sum(!is.na(x))
                                    )), nrow = 1, ncol = nrow(stBalPar)
  )
  maxDatWaBalG <- matrix(as.numeric(apply(waBalBs, 1,
                                          function(x) sum(!is.na(x))
                                    )), nrow = 1, ncol = nrow(waBalPar)
  )
  ## Scores those all-max datasets and pulls the self-care scores
  maxScoSiBalG <- as.data.frame(
                    fscores(scModSiBal, response.pattern = maxDatSiBalG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = siBalMeans, cov = scLTCovSiBal
                    )
  )$F1
  maxScoStBalG <- as.data.frame(
                    fscores(scModStBal, response.pattern = maxDatStBalG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = stBalMeans, cov = scLTCovStBal
                    )
  )$F1
  maxScoWaBalG <- as.data.frame(
                    fscores(scModWaBal, response.pattern = maxDatWaBalG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = waBalMeans, cov = scLTCovWaBal
                    )
  )$F1
  ## Takes the minimum and maximum hypothetical SC scores
  minScoSC <- min(minScoSiBalG, minScoStBalG, minScoWaBalG)
  maxScoSC <- max(maxScoSiBalG, maxScoStBalG, maxScoWaBalG)
  
  ## Repeat the process for self-care min/max finding, but for the balance
  ## assessment area.
  minDatSiBalBal <- matrix(c(rep(0, 6), rep(NA, 35)),
                           nrow = 1, ncol = nrow(siBalPar)
  )
  minDatStBalBal <- matrix(c(rep(0, 12), rep(NA, 35)),
                           nrow = 1, ncol = nrow(stBalPar)
  )
  minDatWaBalBal <- matrix(c(rep(0, 11), rep(NA, 35)),
                           nrow = 1, ncol = nrow(waBalPar)
  )
  minScoSiBalBal <- as.data.frame(
                      fscores(scModSiBal, response.pattern = minDatSiBalBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = siBalMeans, cov = scLTCovSiBal
                      )
  )$F4
  minScoStBalBal <- as.data.frame(
                      fscores(scModStBal, response.pattern = minDatStBalBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = stBalMeans, cov = scLTCovStBal
                      )
  )$F4
  minScoWaBalBal <- as.data.frame(
                      fscores(scModWaBal, response.pattern = minDatWaBalBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = waBalMeans, cov = scLTCovWaBal
                      )
  )$F4
  maxDatSiBalBal <- matrix(c(maxDatSiBalG[, 1:6], rep(NA, 35)),
                           nrow = 1, ncol = nrow(siBalPar)
  )
  maxDatStBalBal <- matrix(c(maxDatStBalG[, 1:12], rep(NA, 35)),
                           nrow = 1, ncol = nrow(stBalPar)
  )
  maxDatWaBalBal <- matrix(c(maxDatWaBalG[, 1:11], rep(NA, 35)),
                           nrow = 1, ncol = nrow(waBalPar)
  )
  maxScoSiBalBal <- as.data.frame(
                      fscores(scModSiBal, response.pattern = maxDatSiBalBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = siBalMeans, cov = scLTCovSiBal
                      )
  )$F4
  maxScoStBalBal <- as.data.frame(
                      fscores(scModStBal, response.pattern = maxDatStBalBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = stBalMeans, cov = scLTCovStBal
                      )
  )$F4
  maxScoWaBalBal <- as.data.frame(
                      fscores(scModWaBal, response.pattern = maxDatWaBalBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = waBalMeans, cov = scLTCovWaBal
                      )
  )$F4
  minScoBal_sc <- min(minScoSiBalBal, minScoStBalBal, minScoWaBalBal)
  maxScoBal_sc <- max(maxScoSiBalBal, maxScoStBalBal, maxScoWaBalBal)
  
  ## Find min/max for UEF assessment area.
  minDatSiBalUEF <- matrix(c(rep(NA, 6), rep(0, 17), rep(NA, 18)),
                           nrow = 1, ncol = nrow(siBalPar)
  )
  minDatStBalUEF <- matrix(c(rep(NA, 12), rep(0, 17), rep(NA, 18)),
                           nrow = 1, ncol = nrow(stBalPar)
  )
  minDatWaBalUEF <- matrix(c(rep(NA, 11), rep(0, 17), rep(NA, 18)),
                           nrow = 1, ncol = nrow(waBalPar)
  )
  minScoSiBalUEF <- as.data.frame(
                      fscores(scModSiBal, response.pattern = minDatSiBalUEF,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = siBalMeans, cov = scLTCovSiBal
                      )
  )$F2
  minScoStBalUEF <- as.data.frame(
                      fscores(scModStBal, response.pattern = minDatStBalUEF,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = stBalMeans, cov = scLTCovStBal
                      )
  )$F2
  minScoWaBalUEF <- as.data.frame(
                      fscores(scModWaBal, response.pattern = minDatWaBalUEF,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = waBalMeans, cov = scLTCovWaBal
                      )
  )$F2
  maxDatSiBalUEF <- matrix(c(rep(NA, 6), maxDatSiBalG[, 7:23], rep(NA, 18)),
                           nrow = 1, ncol = nrow(siBalPar)
  )
  maxDatStBalUEF <- matrix(c(rep(NA, 12), maxDatStBalG[, 13:29], rep(NA, 18)),
                           nrow = 1, ncol = nrow(stBalPar)
  )
  maxDatWaBalUEF <- matrix(c(rep(NA, 11), maxDatWaBalG[, 12:28], rep(NA, 18)),
                           nrow = 1, ncol = nrow(waBalPar)
  )
  maxScoSiBalUEF <- as.data.frame(
                      fscores(scModSiBal, response.pattern = maxDatSiBalUEF,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = siBalMeans, cov = scLTCovSiBal
                      )
  )$F2
  maxScoStBalUEF <- as.data.frame(
                      fscores(scModStBal, response.pattern = maxDatStBalUEF,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = stBalMeans, cov = scLTCovStBal
                      )
  )$F2
  maxScoWaBalUEF <- as.data.frame(
                      fscores(scModWaBal, response.pattern = maxDatWaBalUEF,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = waBalMeans, cov = scLTCovWaBal
                      )
  )$F2
  minScoUEF <- min(minScoSiBalUEF, minScoStBalUEF, minScoWaBalUEF)
  maxScoUEF <- max(maxScoSiBalUEF, maxScoStBalUEF, maxScoWaBalUEF)
  
  ## Find min/max for swallowing assessment area
  minDatSiBalSwl <- matrix(c(rep(NA, 23), rep(0, 12), rep(NA, 6)),
                           nrow = 1, ncol = nrow(siBalPar)
  )
  minDatStBalSwl <- matrix(c(rep(NA, 29), rep(0, 12), rep(NA, 6)),
                           nrow = 1, ncol = nrow(stBalPar)
  )
  minDatWaBalSwl <- matrix(c(rep(NA, 28), rep(0, 12), rep(NA, 6)),
                           nrow = 1, ncol = nrow(waBalPar)
  )
  minScoSiBalSwl <- as.data.frame(
                      fscores(scModSiBal, response.pattern = minDatSiBalSwl,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = siBalMeans, cov = scLTCovSiBal
                      )
  )$F3
  minScoStBalSwl <- as.data.frame(
                      fscores(scModStBal, response.pattern = minDatStBalSwl,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = stBalMeans, cov = scLTCovStBal
                      )
  )$F3
  minScoWaBalSwl <- as.data.frame(
                      fscores(scModWaBal, response.pattern = minDatWaBalSwl,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = waBalMeans, cov = scLTCovWaBal
                      )
  )$F3
  maxDatSiBalSwl <- matrix(c(rep(NA, 23), maxDatSiBalG[, 24:35],
                             rep(NA, 6)), nrow = 1, ncol = nrow(siBalPar)
  )
  maxDatStBalSwl <- matrix(c(rep(NA, 29), maxDatStBalG[, 30:41], rep(NA, 6)),
                           nrow = 1, ncol = nrow(stBalPar)
  )
  maxDatWaBalSwl <- matrix(c(rep(NA, 28), maxDatWaBalG[, 29:40], rep(NA, 6)),
                           nrow = 1, ncol = nrow(waBalPar)
  )
  maxScoSiBalSwl <- as.data.frame(
                      fscores(scModSiBal, response.pattern = maxDatSiBalSwl,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = siBalMeans, cov = scLTCovSiBal
                      )
  )$F3
  maxScoStBalSwl <- as.data.frame(
                      fscores(scModStBal, response.pattern = maxDatStBalSwl,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = stBalMeans, cov = scLTCovStBal
                      )
  )$F3
  maxScoWaBalSwl <- as.data.frame(
                      fscores(scModWaBal, response.pattern = maxDatWaBalSwl,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = waBalMeans, cov = scLTCovWaBal
                      )
  )$F3
  minScoSwl <- min(minScoSiBalSwl, minScoStBalSwl, minScoWaBalSwl)
  maxScoSwl <- max(maxScoSiBalSwl, maxScoStBalSwl, maxScoWaBalSwl)
  
  minScoSC_all <- min(minScoSC, minScoBal_sc, minScoUEF, minScoSwl)
  maxScoSC_all <- max(maxScoSC, maxScoBal_sc, maxScoUEF, maxScoSwl)
  
  }  ## Min/Max scores for SC
  {
  ## See the notes within the area for SC; this is basically a repeat of that
  ## code, but for Mobility and the assessment areas within it.
  minDatWheelG <- matrix(0, nrow = 1, ncol = nrow(wheelPar))
  minDatBothG <- matrix(0, nrow = 1, ncol = nrow(bothPar))
  minDatWalkG <- matrix(0, nrow = 1, ncol = nrow(walkPar))
  minScoWheelG <- as.data.frame(
                    fscores(mobModWheel, response.pattern = minDatWheelG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = wheelMeans, cov = mobLTCovWheel
                    )
  )$F1
  minScoBothG <- as.data.frame(
                   fscores(mobModBoth, response.pattern = minDatBothG,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = bothMeans, cov = mobLTCovBoth
                   )
  )$F1
  minScoWalkG <- as.data.frame(
                   fscores(mobModWalk, response.pattern = minDatWalkG,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = walkMeans, cov = mobLTCovWalk
                   )
  )$F1
  maxDatWheelG <- matrix(apply(wheelBs, 1, function(x) sum(!is.na(x))),
                         nrow = 1, ncol = nrow(wheelPar)
  )
  maxDatBothG <- matrix(apply(bothBs, 1, function(x) sum(!is.na(x))),
                        nrow = 1, ncol = nrow(bothPar)
  )
  maxDatWalkG <- matrix(apply(walkBs, 1, function(x) sum(!is.na(x))),
                        nrow = 1, ncol = nrow(walkPar)
  )
  maxScoWheelG <- as.data.frame(
                    fscores(mobModWheel, response.pattern = maxDatWheelG,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = wheelMeans, cov = mobLTCovWheel
                    )
  )$F1
  maxScoBothG <- as.data.frame(
                   fscores(mobModBoth, response.pattern = maxDatBothG,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = bothMeans, cov = mobLTCovBoth
                   )
  )$F1
  maxScoWalkG <- as.data.frame(
                   fscores(mobModWalk, response.pattern = maxDatWalkG,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = walkMeans, cov = mobLTCovWalk
                   )
  )$F1
  minScoMob <- min(minScoWheelG, minScoBothG, minScoWalkG)
  maxScoMob <- max(maxScoWheelG, maxScoBothG, maxScoWalkG)
  
  minDatWheelBal <- matrix(c(rep(0, 6), rep(NA, 9)),
                           nrow = 1, ncol = nrow(wheelPar)
  )
  minDatBothBal <- matrix(c(rep(0, 12), NA, 0, 0, NA, 0, rep(NA, 6)),
                          nrow = 1, ncol = nrow(bothPar)
  )
  minDatWalkBal <- matrix(c(rep(0, 13), NA, 0, rep(NA, 6)),
                          nrow = 1, ncol = nrow(walkPar)
  )
  minScoWheelBal <- as.data.frame(
                      fscores(mobModWheel, response.pattern = minDatWheelBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = wheelMeans, cov = mobLTCovWheel
                      )
  )$F2
  minScoBothBal <- as.data.frame(
                     fscores(mobModBoth, response.pattern = minDatBothBal,
                             method = 'MAP', theta_lim = c(-6, 6),
                             mean = bothMeans, cov = mobLTCovBoth
                     )
  )$F2
  minScoWalkBal <- as.data.frame(
                     fscores(mobModWalk, response.pattern = minDatWalkBal,
                             method = 'MAP', theta_lim = c(-6, 6),
                             mean = walkMeans, cov = mobLTCovWalk
                     )
  )$F2
  maxDatWheelBal <- matrix(c(maxDatWheelG[, 1:6], rep(NA, 9)),
                           nrow = 1, ncol = nrow(wheelPar)
  )
  maxDatBothBal <- matrix(c(maxDatBothG[, 1:12], NA, maxDatBothG[, 14:15], NA,
                            maxDatBothG[, 17], rep(NA, 6)
                          ), nrow = 1, ncol = nrow(bothPar)
  )
  maxDatWalkBal <- matrix(c(maxDatWalkG[, 1:13], NA, maxDatWalkG[, 15],
                            rep(NA, 6)
                          ), nrow = 1, ncol = nrow(walkPar)
  )
  maxScoWheelBal <- as.data.frame(
                      fscores(mobModWheel, response.pattern = maxDatWheelBal,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = wheelMeans, cov = mobLTCovWheel
                      )
  )$F2
  maxScoBothBal <- as.data.frame(
                     fscores(mobModBoth, response.pattern = maxDatBothBal,
                             method = 'MAP', theta_lim = c(-6, 6),
                             mean = bothMeans, cov = mobLTCovBoth
                     )
  )$F2
  maxScoWalkBal <- as.data.frame(
                     fscores(mobModWalk, response.pattern = maxDatWalkBal,
                             method = 'MAP', theta_lim = c(-6, 6),
                             mean = walkMeans, cov = mobLTCovWalk
                     )
  )$F2
  minScoBal_mob <- min(minScoWheelBal, minScoBothBal, minScoWalkBal)
  maxScoBal_mob <- max(maxScoWheelBal, maxScoBothBal, maxScoWalkBal)
  
  minDatWheelWC <- matrix(c(rep(NA, 6), 0, rep(NA, 3), 0, rep(NA, 3), 0),
                          nrow = 1, ncol = nrow(wheelPar)
  )
  minDatBothWC <- matrix(c(rep(NA, 12), 0, NA, NA, 0, rep(NA, 5), 0, NA),
                         nrow = 1, ncol = nrow(bothPar)
  )
  minDatWalkWC <- matrix(c(rep(NA, 13), 0, rep(NA, 5), 0, NA),
                         nrow = 1, ncol = nrow(walkPar)
  )
  minScoWheelWC <- as.data.frame(
                     fscores(mobModWheel, response.pattern = minDatWheelWC,
                             method = 'MAP', theta_lim = c(-6, 6),
                             mean = wheelMeans, cov = mobLTCovWheel
                     )
  )$F3
  minScoBothWC <- as.data.frame(
                    fscores(mobModBoth, response.pattern = minDatBothWC,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = bothMeans, cov = mobLTCovBoth
                    )
  )$F3
  minScoWalkWC <- as.data.frame(
                    fscores(mobModWalk, response.pattern = minDatWalkWC,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = walkMeans, cov = mobLTCovWalk
                    )
  )$F3
  maxDatWheelWC <- matrix(c(rep(NA, 6), maxDatWheelG[, 7], rep(NA, 3),
                            maxDatWheelG[, 11], rep(NA, 3), maxDatWheelG[, 15]
                          ), nrow = 1, ncol = nrow(wheelPar)
  )
  maxDatBothWC <- matrix(c(rep(NA, 12), maxDatBothG[, 13], NA, NA,
                           maxDatBothG[, 16], rep(NA, 5), maxDatBothG[, 22], NA
                         ), nrow = 1, ncol = nrow(bothPar))
  maxDatWalkWC <- matrix(c(rep(NA, 13), maxDatWalkG[, 14], rep(NA, 5),
                           maxDatWalkG[, 20], NA
                         ), nrow = 1, ncol = nrow(walkPar))
  maxScoWheelWC <- as.data.frame(
                     fscores(mobModWheel, response.pattern = maxDatWheelWC,
                             method = 'MAP', theta_lim = c(-6, 6),
                             mean = wheelMeans, cov = mobLTCovWheel
                     )
  )$F3
  maxScoBothWC <- as.data.frame(
                    fscores(mobModBoth, response.pattern = maxDatBothWC,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = bothMeans, cov = mobLTCovBoth
                    )
  )$F3
  maxScoWalkWC <- as.data.frame(
                    fscores(mobModWalk, response.pattern = maxDatWalkWC,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = walkMeans, cov = mobLTCovWalk
                    )
  )$F3
  minScoWC <- min(minScoWheelWC, minScoBothWC, minScoWalkWC)
  maxScoWC <- max(maxScoWheelWC, maxScoBothWC, maxScoWalkWC)
  
  minDatWheelXfer <- matrix(c(rep(NA, 12), 0, 0, NA),
                            nrow = 1, ncol = nrow(wheelPar)
  )
  minDatBothXfer <- matrix(c(rep(NA, 18), 0, 0, rep(NA, 3)),
                           nrow = 1, ncol = nrow(bothPar)
  )
  minDatWalkXfer <- matrix(c(rep(NA, 16), 0, 0, rep(NA, 3)),
                           nrow = 1, ncol = nrow(walkPar)
  )
  minScoWheelXfer <- as.data.frame(
                       fscores(mobModWheel, response.pattern = minDatWheelXfer,
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = wheelMeans, cov = mobLTCovWheel
                       )
  )$F4
  minScoBothXfer <- as.data.frame(
                      fscores(mobModBoth, response.pattern = minDatBothXfer,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = bothMeans, cov = mobLTCovBoth
                      )
  )$F4
  minScoWalkXfer <- as.data.frame(
                      fscores(mobModWalk, response.pattern = minDatWalkXfer,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = walkMeans, cov = mobLTCovWalk
                      )
  )$F4
  maxDatWheelXfer <- matrix(c(rep(NA, 12), maxDatWheelG[, 13:14], NA),
                            nrow = 1, ncol = nrow(wheelPar)
  )
  maxDatBothXfer <- matrix(c(rep(NA, 18), maxDatBothG[, 19:20], rep(NA, 3)),
                           nrow = 1, ncol = nrow(bothPar)
  )
  maxDatWalkXfer <- matrix(c(rep(NA, 16), maxDatWalkG[, 17:18], rep(NA, 3)),
                           nrow = 1, ncol = nrow(walkPar)
  )
  maxScoWheelXfer <- as.data.frame(
                       fscores(mobModWheel, response.pattern = maxDatWheelXfer,
                               method = 'MAP', theta_lim = c(-6, 6),
                               mean = wheelMeans, cov = mobLTCovWheel
                       )
  )$F4
  maxScoBothXfer <- as.data.frame(
                      fscores(mobModBoth, response.pattern = maxDatBothXfer,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = bothMeans, cov = mobLTCovBoth
                      )
  )$F4
  maxScoWalkXfer <- as.data.frame(
                      fscores(mobModWalk, response.pattern = maxDatWalkXfer,
                              method = 'MAP', theta_lim = c(-6, 6),
                              mean = walkMeans, cov = mobLTCovWalk
                      )
  )$F4
  minScoXfer <- min(minScoWheelXfer, minScoBothXfer, minScoWalkXfer)
  maxScoXfer <- max(maxScoWheelXfer, maxScoBothXfer, maxScoWalkXfer)
  
  minDatCBP <- matrix(c(rep(NA, 7), rep(0, 3), rep(NA, 5)),
                      nrow = 1, ncol = nrow(wheelPar)
  )
  maxDatCBP <- matrix(c(rep(NA, 7), maxDatWheelG[, 8:10], rep(NA, 5)),
                      nrow = 1, ncol = nrow(wheelPar)
  )
  minScoCBP <- as.data.frame(
                 fscores(mobModWheel, response.pattern = minDatCBP,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = wheelMeans, cov = mobLTCovWheel
                 )
  )$F5
  maxScoCBP <- as.data.frame(
                 fscores(mobModWheel, response.pattern = maxDatCBP,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = wheelMeans, cov = mobLTCovWheel
                 )
  )$F5
  
  minScoMob_all <- min(minScoMob, minScoBal_mob, minScoWC, minScoXfer,
                       minScoCBP
  )
  maxScoMob_all <- max(maxScoMob, maxScoBal_mob, maxScoWC, maxScoXfer,
                       maxScoCBP
  )
  
  }  ## Min/Max scores for Mob
  {
  ## This code is almost exactly the same as the SC and Mob code. Once again,
  ## it merely computes min/max scores, but for Cognition.
  minDatAphG <- matrix(0, nrow = 1, ncol = nrow(aphPar))
  minDatCCDG <- matrix(0, nrow = 1, ncol = nrow(ccdPar))
  minDatBIG <- matrix(0, nrow = 1, ncol = nrow(biPar))
  minDatRHDG <- matrix(0, nrow = 1, ncol = nrow(rhdPar))
  minDatSpeG <- matrix(0, nrow = 1, ncol = nrow(spePar))
  minScoAphG <- as.data.frame(
                  fscores(cogModAph, response.pattern = minDatAphG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = aphMeans, cov = cogLTCovAph
                   )
  )$F1
  minScoCCDG <- as.data.frame(
                  fscores(cogModCCD, response.pattern = minDatCCDG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = ccdMeans, cov = cogLTCovCCD
                  )
  )$F1
  minScoBIG <- as.data.frame(
                 fscores(cogModBI, response.pattern = minDatBIG,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = biMeans, cov = cogLTCovBI
                 )
  )$F1
  minScoRHDG <- as.data.frame(
                  fscores(cogModRHD, response.pattern = minDatRHDG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = rhdMeans, cov = cogLTCovRHD
                  )
  )$F1
  minScoSpeG <- as.data.frame(
                  fscores(cogModSpe, response.pattern = minDatSpeG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = speMeans, cov = cogLTCovSpe
                  )
  )$F1
  maxDatAphG <- matrix(apply(aphBs, 1, function(x) sum(!is.na(x))),
                       nrow = 1, ncol = nrow(aphPar)
  )
  maxDatCCDG <- matrix(apply(ccdBs, 1, function(x) sum(!is.na(x))),
                       nrow = 1, ncol = nrow(ccdPar)
  )
  maxDatBIG <- matrix(apply(biBs, 1, function(x) sum(!is.na(x))),
                      nrow = 1, ncol = nrow(biPar)
  )
  maxDatRHDG <- matrix(apply(rhdBs, 1, function(x) sum(!is.na(x))),
                       nrow = 1, ncol = nrow(rhdPar)
  )
  maxDatSpeG <- matrix(apply(speBs, 1, function(x) sum(!is.na(x))),
                       nrow = 1, ncol = nrow(spePar)
  )
  maxScoAphG <- as.data.frame(
                  fscores(cogModAph, response.pattern = maxDatAphG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = aphMeans, cov = cogLTCovAph
                  )
  )$F1
  maxScoCCDG <- as.data.frame(
                  fscores(cogModCCD, response.pattern = maxDatCCDG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = ccdMeans, cov = cogLTCovCCD
                  )
  )$F1
  maxScoBIG <- as.data.frame(
                 fscores(cogModBI, response.pattern = maxDatBIG,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = biMeans, cov = cogLTCovBI
                 )
  )$F1
  maxScoRHDG <- as.data.frame(
                  fscores(cogModRHD, response.pattern = maxDatRHDG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = rhdMeans, cov = cogLTCovRHD
                  )
  )$F1
  maxScoSpeG <- as.data.frame(
                  fscores(cogModSpe, response.pattern = maxDatSpeG,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = speMeans, cov = cogLTCovSpe
                  )
  )$F1
  minScoCog <- min(minScoAphG, minScoCCDG, minScoBIG, minScoRHDG, minScoSpeG)
  maxScoCog <- max(maxScoAphG, maxScoCCDG, maxScoBIG, maxScoRHDG, maxScoSpeG)
  
  minDatCCDSpe <- matrix(c(rep(NA, 9), rep(0, 4), rep(NA, 5)),
                         nrow = 1, ncol = nrow(ccdPar)
  )
  minDatBISpe <- matrix(c(rep(NA, 13), 0, 0, rep(NA, 5)),
                        nrow = 1, ncol = nrow(biPar)
  )
  minDatSpeSpe <- matrix(c(rep(0, 4), rep(NA, 5)),
                         nrow = 1, ncol = nrow(spePar)
  )
  minScoCCDSpe <- as.data.frame(
                    fscores(cogModCCD, response.pattern = minDatCCDSpe,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = ccdMeans, cov = cogLTCovCCD
                    )
  )$F3
  minScoBISpe <- as.data.frame(
                   fscores(cogModBI, response.pattern = minDatBISpe,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = biMeans, cov = cogLTCovBI
                   )
  )$F3
  minScoSpeSpe <- as.data.frame(
                    fscores(cogModSpe, response.pattern = minDatSpeSpe,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = speMeans, cov = cogLTCovSpe
                    )
  )$F3
  maxDatCCDSpe <- matrix(c(rep(NA, 9), maxDatCCDG[, 10:13], rep(NA, 5)),
                         nrow = 1, ncol = nrow(ccdPar)
  )
  maxDatBISpe <- matrix(c(rep(NA, 13), maxDatBIG[, 14:15], rep(NA, 5)),
                        nrow = 1, ncol = nrow(biPar)
  )
  maxDatSpeSpe <- matrix(c(maxDatSpeG[, 1:4], rep(NA, 5)),
                         nrow = 1, ncol = nrow(spePar)
  )
  maxScoCCDSpe <- as.data.frame(
                    fscores(cogModCCD, response.pattern = maxDatCCDSpe,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = ccdMeans, cov = cogLTCovCCD
                    )
  )$F3
  maxScoBISpe <- as.data.frame(
                   fscores(cogModBI, response.pattern = maxDatBISpe,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = biMeans, cov = cogLTCovBI
                   )
  )$F3
  maxScoSpeSpe <- as.data.frame(
                    fscores(cogModSpe, response.pattern = maxDatSpeSpe,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = speMeans, cov = cogLTCovSpe
                    )
  )$F3
  minScoSpe <- min(minScoCCDSpe, minScoBISpe, minScoSpeSpe)
  maxScoSpe <- max(maxScoCCDSpe, maxScoBISpe, maxScoSpeSpe)
  
  minDatCCDMem <- matrix(c(rep(0, 9), rep(NA, 9)),
                         nrow = 1, ncol = nrow(ccdPar)
  )
  minDatBIMem <- matrix(c(rep(0, 6), rep(NA, 4), rep(0, 3), rep(NA, 7)),
                        nrow = 1, ncol = nrow(biPar)
  )
  minDatRHDMem <- matrix(c(rep(0, 7), NA, 0, rep(NA, 7)),
                         nrow = 1, ncol = nrow(rhdPar)
  )
  minScoCCDMem <- as.data.frame(
                    fscores(cogModCCD, response.pattern = minDatCCDMem,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = ccdMeans, cov = cogLTCovCCD
                    )
  )$F4
  minScoBIMem <- as.data.frame(
                   fscores(cogModBI, response.pattern = minDatBIMem,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = biMeans, cov = cogLTCovBI
                   )
  )$F4
  minScoRHDMem <- as.data.frame(
                    fscores(cogModRHD, response.pattern = minDatRHDMem,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = rhdMeans, cov = cogLTCovRHD
                    )
  )$F4
  maxDatCCDMem <- matrix(c(maxDatCCDG[, 1:9], rep(NA, 9)),
                         nrow = 1, ncol = nrow(ccdPar)
  )
  maxDatBIMem <- matrix(c(maxDatBIG[, 1:6], rep(NA, 4), maxDatBIG[, 11:13],
                          rep(NA, 7)
                        ), nrow = 1, ncol = nrow(biPar)
  )
  maxDatRHDMem <- matrix(c(maxDatRHDG[, 1:7], NA, maxDatRHDG[, 9], rep(NA, 7)),
                         nrow = 1, ncol = nrow(rhdPar)
  )
  maxScoCCDMem <- as.data.frame(
                    fscores(cogModCCD, response.pattern = maxDatCCDMem,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = ccdMeans, cov = cogLTCovCCD
                    )
  )$F4
  maxScoBIMem <- as.data.frame(
                   fscores(cogModBI, response.pattern = maxDatBIMem,
                           method = 'MAP', theta_lim = c(-6, 6),
                           mean = biMeans, cov = cogLTCovBI
                   )
  )$F4
  maxScoRHDMem <- as.data.frame(
                    fscores(cogModRHD, response.pattern = maxDatRHDMem,
                            method = 'MAP', theta_lim = c(-6, 6),
                            mean = rhdMeans, cov = cogLTCovRHD
                    )
  )$F4
  minScoMem <- min(minScoCCDMem, minScoBIMem, minScoRHDMem)
  maxScoMem <- max(maxScoCCDMem, maxScoBIMem, maxScoRHDMem)
  
  minDatAphCom <- matrix(c(NA, rep(0, 6), rep(NA, 3), rep(0, 3), NA, NA, 0,
                           rep(NA, 5)
                         ), nrow = 1, ncol = nrow(aphPar)
  )
  maxDatAphCom <- matrix(c(NA, maxDatAphG[, 2:7], rep(NA, 3),
                           maxDatAphG[, 11:13], NA, NA, maxDatAphG[, 15],
                           rep(NA, 5)
                         ), nrow = 1, ncol = nrow(aphPar)
  )
  minScoCom <- as.data.frame(
                 fscores(cogModAph, response.pattern = minDatAphCom,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = aphMeans, cov = cogLTCovAph
                 )
  )$F5
  maxScoCom <- as.data.frame(
                 fscores(cogModAph, response.pattern = maxDatAphCom,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = aphMeans, cov = cogLTCovAph
                 )
  )$F5
  
  minDatAphWCom <- matrix(c(rep(NA, 7), rep(0, 3), rep(NA, 11)),
                          nrow = 1, ncol = nrow(aphPar)
  )
  maxDatAphWCom <- matrix(c(rep(NA, 7), maxDatAphG[, 8:10], rep(NA, 11)),
                          nrow = 1, ncol = nrow(aphPar)
  )
  minScoWCom <- as.data.frame(
                  fscores(cogModAph, response.pattern = minDatAphWCom,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = aphMeans, cov = cogLTCovAph
                  )
  )$F6
  maxScoWCom <- as.data.frame(
                  fscores(cogModAph, response.pattern = maxDatAphWCom,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = aphMeans, cov = cogLTCovAph
                  )
  )$F6
  
  minDatAphComp <- matrix(c(rep(NA, 13), 0, 0, rep(NA, 6)),
                          nrow = 1, ncol = nrow(aphPar)
  )
  maxDatAphComp <- matrix(c(rep(NA, 13), maxDatAphG[, 14:15], rep(NA, 6)),
                          nrow = 1, ncol = nrow(aphPar)
  )
  minScoComp <- as.data.frame(
                  fscores(cogModAph, response.pattern = minDatAphComp,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = aphMeans, cov = cogLTCovAph
                  )
  )$F7
  maxScoComp <- as.data.frame(
                  fscores(cogModAph, response.pattern = maxDatAphComp,
                          method = 'MAP', theta_lim = c(-6, 6),
                          mean = aphMeans, cov = cogLTCovAph
                  )
  )$F7
  
  minDatBIAgi <- matrix(c(rep(NA, 6), rep(0, 4), rep(NA, 10)),
                        nrow = 1, ncol = nrow(biPar)
  )
  maxDatBIAgi <- matrix(c(rep(NA, 6), maxDatBIG[, 7:10], rep(NA, 10)),
                        nrow = 1, ncol = nrow(biPar)
  )
  minScoAgi <- as.data.frame(
                 fscores(cogModBI, response.pattern = minDatBIAgi,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = biMeans, cov = cogLTCovBI
                 )
  )$F8
  maxScoAgi <- as.data.frame(
                 fscores(cogModBI, response.pattern = maxDatBIAgi,
                         method = 'MAP', theta_lim = c(-6, 6),
                         mean = biMeans, cov = cogLTCovBI
                 )
  )$F8
  
  minScoCog_all <- min(minScoCog, minScoSpe, minScoMem, minScoCom, minScoWCom,
                       minScoComp, minScoAgi
  )
  maxScoCog_all <- max(maxScoCog, maxScoSpe, maxScoMem, maxScoCom, maxScoWCom,
                       maxScoComp, maxScoAgi
  )
  }  ## Min/Max scores for cog
  
  ## Formats the predictive models into a nice consistent order.
  scPreds <- scPreds[order(scPreds$msg, scPreds$cmg, scPreds$scgroup,
                           scPreds$longstay, scPreds$time
                     )
  , ]
  mobPreds <- mobPreds[order(mobPreds$msg, mobPreds$cmg, mobPreds$mobgroup,
                             mobPreds$longstay, mobPreds$time
                       )
  , ]
  mobPreds$cmg <- sprintf('%04d', mobPreds$cmg)
  cogPreds <- cogPreds[order(cogPreds$msg, cogPreds$cmg, cogPreds$coggroup,
                             cogPreds$longstay, cogPreds$time
                       )
  , ]
  }   # Model setup
  
  {
  ## Re-opens connection to EDW
  awsCon <- DBI::dbConnect(RPostgres::Postgres(),
                           host = host,
                           port = port, dbname = dbname,
                           user = user, password = pwd
  )
  
  ## Pulls the LoS x CMG table from the EDW.
  cmglos <- dbGetQuery(awsCon, 'SELECT * FROM sandboxomsa.cmg_los;')
  
  ## Selects current inpatients in Dr. Harvey's service. When we start rolling
  ## this out to other floors, I'll have to build a "Select your service" intro
  ## screen and save that selection as reactive value in the uv object.
  ## Selecting a doctor's name could then be pushed forward to run this query.
  
  ## First, we check to make sure that table containing current patients has
  ## been updated. If so, we can fasttrack the startup. Otherwise, it has to
  ## run the longer queries.
  updateCheck <- dbGetQuery(awsCon,
                            'SELECT table_name, updt_ts
                             FROM outcomedm.current_patients_last_update;'
  )
  uc <- as.Date(format(as.POSIXct(updateCheck$updt_ts, 'GMT'),
                                  tz = 'America/Chicago',
                                  '%Y-%m-%d'
  ))
  uc <- ifelse(uc < Sys.Date(), 0, 1)
  
  demo <- 0
  
  if(uc == 0 || demo == 1){
    currentQ <- paste("
      SELECT fin, provider_type, provider_name, disch_ind, reg_dt_tm
      FROM outcomedm.encntr_all
      INNER JOIN outcomedm.view_encntr_provider_reltn
        ON encntr_all.encntr_id = view_encntr_provider_reltn.encntr_id
      WHERE disch_ind = 'N' AND
            provider_type = 'Attending Physician' AND
            provider_name = 'Ripley, David L MD' AND
            end_effective_dt_tm >= current_date AND
            active_ind = 1 AND
            priority_seq = 0 AND
            encntr_type = 'Inpatient';
    ")
    curPat <- dbGetQuery(awsCon, currentQ)
  }else{
    curPat <- dbGetQuery(awsCon, 'SELECT fin, provider_type, provider_name,
                                         disch_ind, reg_dt_tm
                                  FROM outcomedm.current_patients'
    )
    curPat <- curPat[curPat$provider_name == 'Ripley, David L MD', ]
  }

  if(demo == 1){
    rmQ <- paste("
      SELECT fin, provider_type, provider_name, disch_ind, reg_dt_tm
      FROM outcomedm.encntr_all
      INNER JOIN outcomedm.view_encntr_provider_reltn
        ON encntr_all.encntr_id = view_encntr_provider_reltn.encntr_id
      WHERE provider_type = 'Attending Physician' AND
            priority_seq = 0 AND
            fin IN ('5768522');
    ")
  
    rmDF <- dbGetQuery(awsCon, rmQ)
    rmDF <- rmDF[!duplicated(rmDF$fin), ]
  
    curPat <- rbind(curPat, rmDF)
  }
  
  ## This may seem like an odd thing to do, but pulling a single row at a time
  ## from outcomedm.encntr_all is much faster than pulling in batch. I ran a
  ## simulation to determine this. At this point, any speedup I can get upon
  ## loading, I'll take.
  lis <- vector('list', length(curPat))
  for(i in 1:nrow(curPat)){
    lis[[i]] <- dbGetQuery(
      awsCon, paste("SELECT fin, mrn, patient_name, med_service, cmg_cd,
                            loc_nurse_unit_floor, reg_dt_tm, est_depart_dt_tm,
                            admit_age
                     FROM outcomedm.encntr_all
                     WHERE fin = '", as.numeric(curPat$fin[i]), "';", sep = ''
              )
    )
  }
  lisAll <- do.call('rbind', lis)
  ## Drops patients without a floor designation. This is probably not necessary
  ## anymore.
  if(any(is.na(lisAll$loc_nurse_unit_floor))){
    hp <- lisAll[!is.na(lisAll$loc_nurse_unit_floor), ]
  }else{
    hp <- lisAll
  }
  ## Throws out duplicates. Can happen when a patient is reassigned to another
  ## doctor, to another room, to another floor, or has their RIC (and,
  ## therefore, CMG) changed. In any case, there's a lot of things that cause
  ## duplicates here, and we don't want them.
  if(any(duplicated(hp))){
    hp <- hp[-which(duplicated(hp)), ]
  }
  ## Drops patients who are duplicated because of multiple CMGs. This is
  ## another part that will have to be edited for rollout on different floors.
  ## This conditional removes patients with non-stroke CMGs.
  # if(any(duplicated(hp[, c(1:3, 6:7)]))){
  #   hp <- hp[grep('01..', hp$cmg_cd), ]
  # }
  colnames(hp) <- c('FIN', 'MRN', 'Name', 'MedicalService', 'CMG', 'Floor',
                    'Admit', 'ExpDepart', 'Age'
  )
  hp$AttendingPhysician <- 'Ripley, David L MD'

  ## This date formatting is used throughout the document. The EDW has all
  ## times as GMT. This converts them to Chicago time (GMT -5/-6).
  hp$Admit <- as.Date(format(as.POSIXct(hp$Admit, 'GMT'),
                             tz = 'America/Chicago',
                             '%Y-%m-%d'
  ))
  hp$ExpDepart <- as.Date(format(as.POSIXct(hp$ExpDepart, 'GMT'),
                                 tx = 'America/Chicago',
                                 '%Y-%m-%d'
  ))
  
  ## All of the queries below follow the same basic format. The AQ items are
  ## pulled from each measure and joined with outcomedm.fin_mrn to obtain the
  ## matching MRN. The second paste() function in the middle of each query
  ## results in a properly comma-separated, bracket-enclosed list of FINs to
  ## pull from the table. The forward slashes are necessary escape characters
  ## for the single quotes enclosing each FIN.
  
  ## The time/date formatting is in a conditional because attempting to format
  ## the date of an empty data.frame with throw an error and cause the
  ## dashboard to crash while loading.
  
  ## Function in Sitting Test query
  if(uc == 0 || demo == 1){
    # fistList <- vector('list', nrow(hp))
    # for(i in 1:length(fistList)){
    #   fistList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, anteriornudge, staticsitting,
    #              sittingeyesclosed, sittingliftfoot, lateralreach,
    #              pickupfromfloor, assessmentdate
    #       FROM outcomedm.fist_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON fist_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # fist <- do.call('rbind', fistList)
    fistQuery <- paste("
      SELECT mrn, fin_mrn.fin, anteriornudge, staticsitting, sittingeyesclosed,
             sittingliftfoot, lateralreach, pickupfromfloor, assessmentdate
      FROM outcomedm.fist_frmt
      INNER JOIN outcomedm.fin_mrn
        ON fist_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    fist <- dbGetQuery(awsCon, fistQuery)
  }else{
    fist <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_fist_frmt'
    )
  }
  colnames(fist) <- c('MRN', 'FIN', 'anteriorNudge', 'staticSitting',
                      'sittingEyesClosed', 'sittingLiftFoot', 'lateralReach',
                      'pickUpFromFloor', 'assessmentDate'
  )
  fist <- fist[fist$FIN %in% hp$FIN, ]
  if(dim(fist)[1] > 0){
    fist$assessmentDate <- as.Date(format(
                                     as.POSIXct(fist$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }

  ## Berg Balance Scale query
  if(uc == 0 || demo == 1){
    # bbsList <- vector('list', nrow(hp))
    # for(i in 1:length(bbsList)){
    #   bbsList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, standingunsupported, standingtositting,
    #              standingunsupportedfeettogether,
    #              reachforwardoutstretchedarmStand, pickupobjectfloorstanding,
    #              turn360, assessmentdate
    #       FROM outcomedm.bergbalance_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON bergbalance_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # bbs <- do.call('rbind', bbsList)
    bbsQuery <- paste("
      SELECT mrn, fin_mrn.fin, standingunsupported, standingtositting,
             standingunsupportedfeettogether, reachforwardoutstretchedarmStand,
             pickupobjectfloorstanding, turn360, assessmentdate
      FROM outcomedm.bergbalance_frmt
      INNER JOIN outcomedm.fin_mrn
        ON bergbalance_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    bbs <- dbGetQuery(awsCon, bbsQuery)
  }else{
    bbs <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_bergbalance_frmt'
    )
  }
  colnames(bbs) <- c('MRN', 'FIN', 'standingUnsupported', 'standingToSitting',
                     'standingUnsupportedFeetTogether',
                     'reachForwardOutstretchedArmStand',
                     'pickUpObjectFloorStanding', 'turn360', 'assessmentDate'
  )
  bbs <- bbs[bbs$FIN %in% hp$FIN, ]
  if(dim(bbs)[1] > 0){
    bbs$assessmentDate <- as.Date(format(
                                    as.POSIXct(bbs$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }
  
  ## Functional Gait Assessment query
  if(uc == 0 || demo == 1){
    # fgaList <- vector('list', nrow(hp))
    # for(i in 1:length(fgaList)){
    #   fgaList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, levelsurface, verticalheadturns,
    #              pivotturn, stepoverobstacle, ambulatingbackwards,
    #              assessmentdate
    #       FROM outcomedm.functional_gait_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON functional_gait_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # fga <- do.call('rbind', fgaList)
    fgaQuery <- paste("
      SELECT mrn, fin_mrn.fin, levelsurface, verticalheadturns, pivotturn,
             stepoverobstacle, ambulatingbackwards, assessmentdate
      FROM outcomedm.functional_gait_frmt
      INNER JOIN outcomedm.fin_mrn
        ON functional_gait_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    fga <- dbGetQuery(awsCon, fgaQuery)
  }else{
    fga <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_functional_gait_frmt'
    )
  }
  colnames(fga) <- c('MRN', 'FIN', 'levelSurface', 'verticalHeadTurns',
                     'pivotTurn', 'stepOverObstacle', 'ambulatingBackwards',
                     'assessmentDate'
  )
  fga <- fga[fga$FIN %in% hp$FIN, ]
  if(dim(fga)[1] > 0){
    fga$assessmentDate <- as.Date(format(
                                    as.POSIXct(fga$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }

  ## Action Research Arm Test query
  if(uc == 0 || demo == 1){
    # aratList <- vector('list', nrow(hp))
    # for(i in 1:length(aratList)){
    #   aratList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, graspwood10, griptube2p25,
    #              pinchBearing3rd, grosshandtomouth, assessmentDate
    #       FROM outcomedm.arat_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON arat_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # arat <- do.call('rbind', aratList)
    aratQuery <- paste("
      SELECT mrn, fin_mrn.fin, graspwood10, griptube2p25, pinchBearing3rd,
             grosshandtomouth, assessmentDate
      FROM outcomedm.arat_frmt
      INNER JOIN outcomedm.fin_mrn
        ON arat_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    arat <- dbGetQuery(awsCon, aratQuery)
  }else{
    arat <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_arat_frmt'
    )
  }
  colnames(arat) <- c('MRN', 'FIN', 'graspWood10', 'gripTube2p25',
                      'pinchBearing3rd', 'grossHandToMouth',
                      'assessmentDate'
  )
  arat <- arat[arat$FIN %in% hp$FIN, ]
  if(dim(arat)[1] > 0){
    arat$assessmentDate <- as.Date(format(
                                     as.POSIXct(arat$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }
    
  ## Nine Hole/Peg Test query
  if(uc == 0 || demo == 1){
    # nhpList <- vector('list', nrow(hp))
    # for(i in 1:length(nhpList)){
    #   nhpList[[i]]<- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, scoreleft, scoreright, assessmentdate
    #       FROM outcomedm.ninehole_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON ninehole_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # nhp <- do.call('rbind', nhpList)
    nhpQuery <- paste("
      SELECT mrn, fin_mrn.fin, scoreleft, scoreright, assessmentdate
      FROM outcomedm.ninehole_frmt
      INNER JOIN outcomedm.fin_mrn
        ON ninehole_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    nhp <- dbGetQuery(awsCon, nhpQuery)
  }else{
    nhp <- dbGetQuery(awsCon, 'SELECT *
                      FROM outcomedm.current_ninehole_frmt'
    )
  }
  nhp <- nhp[, 1:5]
  colnames(nhp) <- c('MRN', 'FIN', 'scoreLeftNHP', 'scoreRightNHP',
                     'assessmentDate'
  )
  nhp <- nhp[nhp$FIN %in% hp$FIN, ]
  if(dim(nhp)[1] > 0){
    nhp$assessmentDate <- as.Date(format(
                                    as.POSIXct(nhp$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }

  ## Box & Blocks query
  if(uc == 0 || demo == 1){
    # bbList <- vector('list', nrow(hp))
    # for(i in 1:length(bbList)){
    #   bbList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, scoreleft, scoreright, assessmentdate
    #       FROM outcomedm.boxblocks_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON boxblocks_frmt.fin = fin_mrn.fin
    #       WHERE boxblocks_frmt.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # bb <- do.call('rbind', bbList)
    bbQuery <- paste("
      SELECT mrn, fin_mrn.fin, scoreleft, scoreright, assessmentdate
      FROM outcomedm.boxblocks_frmt
      INNER JOIN outcomedm.fin_mrn
        ON boxblocks_frmt.fin = fin_mrn.fin
      WHERE boxblocks_frmt.fin IN (\'", paste(hp$FIN,
                                              collapse = "\', \'"
                                        ), '\');', sep = ''
    )
    bb <- dbGetQuery(awsCon, bbQuery)
  }else{
    bb <- dbGetQuery(awsCon, 'SELECT *
                              FROM outcomedm.current_boxblocks_frmt'
    )
  }
  colnames(bb) <- c('MRN', 'FIN', 'scoreLeftBB', 'scoreRightBB',
                    'assessmentDate'
  )
  bb <- bb[bb$FIN %in% hp$FIN, ]
  if(dim(bb)[1] > 0){
    bb$assessmentDate <- as.Date(format(
                                   as.POSIXct(bb$assessmentDate, 'GMT'),
                                   tz = 'America/Chicago',
                                   '%Y-%m-%d'
                                 )
    )
  }
  
  ## Bimanual Function Test query
  if(uc == 0 || demo == 1){
    # bftList <- vector('list', nrow(hp))
    # for(i in 1:length(bftList)){
    #   bftList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, button, jar, cut, fold, paperclip, assessmentdate
    #       FROM outcomedm.bimanual_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON bimanual_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # bft <- do.call('rbind', bftList)
    bftQuery <- paste("
      SELECT mrn, fin_mrn.fin, button, jar, cut, fold, paperclip, assessmentdate
      FROM outcomedm.bimanual_frmt
      INNER JOIN outcomedm.fin_mrn
        ON bimanual_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    bft <- dbGetQuery(awsCon, bftQuery)
  }else{
    bft <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_bimanual_frmt'
    )
  }
  colnames(bft) <- c('MRN', 'FIN', 'button', 'jar', 'cut', 'fold', 'paperclip',
                     'assessmentDate'
  )
  bft <- bft[bft$FIN %in% hp$FIN, ]
  if(dim(bft)[1] > 0){
    bft$assessmentDate <- as.Date(format(
                                    as.POSIXct(bft$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }

  ## Pinch/Grip Strength query
  if(uc == 0 || demo == 1){
    # pgList <- vector('list', nrow(hp))
    # for(i in 1:length(pgList)){
    #   pgList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, keypinchrightaverage, keypinchleftaverage,
    #              griprightaverage, gripleftaverage, assessmentdate
    #       FROM outcomedm.pinchgrip_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON pinchgrip_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # pg <- do.call('rbind', pgList)
    pgQuery <- paste("
      SELECT mrn, fin_mrn.fin, keypinchrightaverage, keypinchleftaverage,
             griprightaverage, gripleftaverage, assessmentdate
      FROM outcomedm.pinchgrip_frmt
      INNER JOIN outcomedm.fin_mrn
        ON pinchgrip_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    pg <- dbGetQuery(awsCon, pgQuery)
  }else{
    pg <- dbGetQuery(awsCon, 'SELECT *
                              FROM outcomedm.current_pinchgrip_frmt'
    )
  }
  pg <- pg[, 1:7]
  colnames(pg) <- c('MRN', 'FIN', 'keyPR', 'keyPL', 'gripR', 'gripL',
                    'assessmentDate'
  )
  pg <- pg[pg$FIN %in% hp$FIN, ]
  if(dim(pg)[1] > 0){
    pg$assessmentDate <- as.Date(format(
                                   as.POSIXct(pg$assessmentDate, 'GMT'),
                                   tz = 'America/Chicago',
                                   '%Y-%m-%d'
                                 )
    )
  }

  ## Mann's Assessment of Swallowing Ability query
  ## As an aside, yes, "tonguecoordition" is misspelled. It's that way on both
  ## the EDW and in Cerner.
  if(uc == 0 || demo == 1){
    # masaList <- vector('list', nrow(hp))
    # for(i in 1:length(masaList)){
    #   masaList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, saliva, tonguemovement, tonguestrength,
    #              tonguecoordition, oralpreparation, bolusclearance, oraltransit,
    #              voluntarycough, pharyngealphase, pharyngealresponse, assessmentdate
    #       FROM outcomedm.masa_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON masa_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # masa <- do.call('rbind', masaList)
    masaQuery <- paste("
      SELECT mrn, fin_mrn.fin, saliva, tonguemovement, tonguestrength,
             tonguecoordition, oralpreparation, bolusclearance, oraltransit,
             voluntarycough, pharyngealphase, pharyngealresponse, assessmentdate
      FROM outcomedm.masa_frmt
      INNER JOIN outcomedm.fin_mrn
        ON masa_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    masa <- dbGetQuery(awsCon, masaQuery)
  }else{
    masa <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_masa_frmt'
    )
  }
  colnames(masa) <- c('MRN', 'FIN', 'saliva', 'tongueMovement',
                      'tongueStrength', 'tongueCoordination',
                      'oralPreparation', 'bolusClearance', 'oralTransit',
                      'voluntaryCough', 'pharyngealPhase',
                      'pharyngealResponse', 'assessmentDate'
  )
  masa <- masa[masa$FIN %in% hp$FIN, ]
  if(dim(masa)[1] > 0){
    masa$assessmentDate <- as.Date(format(
                                     as.POSIXct(masa$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }

  ## Funtional Oral Intake Scale and RIC Dysphagia Supervision Scale query
  if(uc == 0 || demo == 1){
    # swlList <- vector('list', nrow(hp))
    # for(i in 1:length(swlList)){
    #   swlList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, score, dysphagiasupervisionlevel, assessmentdate
    #       FROM outcomedm.fois_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON fois_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # swl <- do.call('rbind', swlList)
    swlQuery <- paste("
      SELECT mrn, fin_mrn.fin, score, dysphagiasupervisionlevel, assessmentdate
      FROM outcomedm.fois_frmt
      INNER JOIN outcomedm.fin_mrn
        ON fois_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    swl <- dbGetQuery(awsCon, swlQuery)
  }else{
    swl <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_fois_frmt'
    )
  }
  colnames(swl) <- c('MRN', 'FIN', 'fois', 'dysphagiaSupervisionLevel',
                     'assessmentDate'
  )
  swl <- swl[swl$FIN %in% hp$FIN, ]
  if(dim(swl)[1] > 0){
    swl$assessmentDate <- as.Date(format(
                                    as.POSIXct(swl$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }
  
  ## Pressure Relief query
  if(uc == 0 || demo == 1){
    # pRelList <- vector('list', nrow(hp))
    # for(i in 1:length(pRelList)){
    #   pRelList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, score, assessmentdate
    #       FROM outcomedm.pressurerelief_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON pressurerelief_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # pRel <- do.call('rbind', pRelList)
    pRelQuery <- paste("
      SELECT mrn, fin_mrn.fin, score, assessmentdate
      FROM outcomedm.pressurerelief_frmt
      INNER JOIN outcomedm.fin_mrn
        ON pressurerelief_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    pRel <- dbGetQuery(awsCon, pRelQuery)
  }else{
    pRel <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_pressurerelief_frmt'
    )
  }
  colnames(pRel) <- c('MRN', 'FIN', 'score', 'assessmentDate')
  pRel <- pRel[pRel$FIN %in% hp$FIN, ]
  if(dim(pRel)[1] > 0){
    pRel$assessmentDate <- as.Date(format(
                                     as.POSIXct(pRel$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }
  
  ## Functional Mobility Scale query (not that anyone administers this one...)
  if(uc == 0 || demo == 1){
    # fmsList <- vector('list', nrow(hp))
    # for(i in 1:length(fmsList)){
    #   fmsList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, supinetolongorringsit, shortsittomatorbed,
    #              selfrangeofmotionmanagement, assessmentdate
    #       FROM outcomedm.fms_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON fms_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # fms <- do.call('rbind', fmsList)
    fmsQuery <- paste("
      SELECT mrn, fin_mrn.fin, supinetolongorringsit, shortsittomatorbed,
             selfrangeofmotionmanagement, assessmentdate
      FROM outcomedm.fms_frmt
      INNER JOIN outcomedm.fin_mrn
        ON fms_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    fms <- dbGetQuery(awsCon, fmsQuery)
  }else{
    fms <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_fms_frmt'
    )
  }
  colnames(fms) <- c('MRN', 'FIN', 'supine2LongSit', 'shortSit2Mat', 'selfROM',
                     'assessmentDate'
  )
  fms <- fms[fms$FIN %in% hp$FIN, ]
  if(dim(fms)[1] > 0){
    fms$assessmentDate <- as.Date(format(
                                    as.POSIXct(fms$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }
  
  ## Five Times Sit-To-Stand query
  if(uc == 0 || demo == 1){
    # fiveTimesList <- vector('list', nrow(hp))
    # for(i in 1:length(fiveTimesList)){
    #   fiveTimesList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, score, assessmentdate
    #       FROM outcomedm.fivetimes_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON fivetimes_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # fiveTimes <- do.call('rbind', fiveTimesList)
    fiveTimesQuery <- paste("
      SELECT mrn, fin_mrn.fin, score, assessmentdate
      FROM outcomedm.fivetimes_frmt
      INNER JOIN outcomedm.fin_mrn
        ON fivetimes_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    fiveTimes <- dbGetQuery(awsCon, fiveTimesQuery)
  }else{
    fiveTimes <- dbGetQuery(awsCon, 'SELECT *
                                     FROM outcomedm.current_fivetimes_frmt'
    )
  }
  colnames(fiveTimes) <- c('MRN', 'FIN', 'fiveTimes', 'assessmentDate')
  fiveTimes <- fiveTimes[fiveTimes$FIN %in% hp$FIN, ]
  if(dim(fiveTimes)[1] > 0){
    fiveTimes$assessmentDate <- as.Date(
                                  format(
                                    as.POSIXct(fiveTimes$assessmentDate,
                                               'GMT'
                                    ),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }
  
  ## Ten Meter Walk query
  if(uc == 0 || demo == 1){
    # tenMeterList <- vector('list', nrow(hp))
    # for(i in 1:length(tenMeterList)){
    #   tenMeterList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, selfselecttrial1, selfselecttrial2, assessmentdate
    #       FROM outcomedm.tenmeter_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON tenmeter_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # tenMeter <- do.call('rbind', tenMeterList)
    tenMeterQuery <- paste("
      SELECT mrn, fin_mrn.fin, selfselecttrial1, selfselecttrial2, assessmentdate
      FROM outcomedm.tenmeter_frmt
      INNER JOIN outcomedm.fin_mrn
        ON tenmeter_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    tenMeter <- dbGetQuery(awsCon, tenMeterQuery)
  }else{
    tenMeter <- dbGetQuery(awsCon, 'SELECT *
                                    FROM outcomedm.current_tenmeter_frmt'
    )
  }
  colnames(tenMeter) <- c('MRN', 'FIN', 'tenMeter1', 'tenMeter2',
                          'assessmentDate'
  )
  tenMeter <- tenMeter[tenMeter$FIN %in% hp$FIN, ]
  if(dim(tenMeter)[1] > 0){
    tenMeter$assessmentDate <- as.Date(format(
                                         as.POSIXct(tenMeter$assessmentDate,
                                                    'GMT'
                                         ),
                                         tz = 'America/Chicago',
                                         '%Y-%m-%d'
                                       )
    )
  }
  
  ## Six Minute Walk query
  if(uc == 0 || demo == 1){
    # sixMinWList <- vector('list', nrow(hp))
    # for(i in 1:length(sixMinWList)){
    #   sixMinWList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, distanceft, assessmentdate
    #       FROM outcomedm.sixminutes_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON sixminutes_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # sixMinW <- do.call('rbind', sixMinWList)
    sixMinWQuery <- paste("
      SELECT mrn, fin_mrn.fin, distanceft, assessmentdate
      FROM outcomedm.sixminutes_frmt
      INNER JOIN outcomedm.fin_mrn
        ON sixminutes_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    sixMinW <- dbGetQuery(awsCon, sixMinWQuery)
  }else{
    sixMinW <- dbGetQuery(awsCon, 'SELECT *
                                   FROM outcomedm.current_sixminutes_frmt'
    )
  }
  colnames(sixMinW) <- c('MRN', 'FIN', 'sixMinW', 'assessmentDate')
  sixMinW <- sixMinW[sixMinW$FIN %in% hp$FIN, ]
  if(dim(sixMinW)[1] > 0){
    sixMinW$assessmentDate <- as.Date(format(
                                        as.POSIXct(sixMinW$assessmentDate,
                                                   'GMT'
                                        ),
                                        tz = 'America/Chicago',
                                        '%Y-%m-%d'
                                      )
    )
  }
  
  ## Six Minute Push query
  if(uc == 0 || demo == 1){
    # sixMinPList <- vector('list', nrow(hp))
    # for(i in 1:length(sixMinPList)){
    #   sixMinPList[[i]] <- dbGetQuery(awsCon, 
    #     paste("
    #       SELECT mrn, fin_mrn.fin, distancefeet, assessmentdate
    #       FROM outcomedm.sixminutepush_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON sixminutepush_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # sixMinP <- do.call('rbind', sixMinPList)
    sixMinPQuery <- paste("
      SELECT mrn, fin_mrn.fin, distancefeet, assessmentdate
      FROM outcomedm.sixminutepush_frmt
      INNER JOIN outcomedm.fin_mrn
        ON sixminutepush_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    sixMinP <- dbGetQuery(awsCon, sixMinPQuery)
  }else{
    sixMinP <- dbGetQuery(awsCon, 'SELECT *
                                   FROM outcomedm.current_sixminutepush_frmt'
    )
  }
  colnames(sixMinP) <- c('MRN', 'FIN', 'sixMinP', 'assessmentDate')
  sixMinP <- sixMinP[sixMinP$FIN %in% hp$FIN, ]
  if(dim(sixMinP)[1] > 0){
    sixMinP$assessmentDate <- as.Date(format(
                                        as.POSIXct(sixMinP$assessmentDate,
                                                   'GMT'
                                        ),
                                        tz = 'America/Chicago',
                                        '%Y-%m-%d'
                                      )
    )
  }
  
  ## Orientation Log query
  if(uc == 0 || demo == 1){
    # ologList <- vector('list', nrow(hp))
    # for(i in 1:length(ologList)){
    #   ologList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, city, nameofhospital, monthcurrent, dayofweek,
    #              etiology, pathology, assessmentdate
    #       FROM outcomedm.olog_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON outcomedm.olog_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # olog <- do.call('rbind', ologList)
    ologQuery <- paste("
      SELECT mrn, fin_mrn.fin, city, nameofhospital, monthcurrent, dayofweek,
             etiology, pathology, assessmentdate
      FROM outcomedm.olog_frmt
      INNER JOIN outcomedm.fin_mrn
        ON outcomedm.olog_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    olog <- dbGetQuery(awsCon, ologQuery)
  }else{
    olog <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_olog_frmt'
    )
  }
  colnames(olog) <- c('MRN', 'FIN', 'city', 'nameOfHospital', 'monthCurrent',
                      'dayOfWeek', 'etiology', 'pathology', 'assessmentDate'
  )
  olog <- olog[olog$FIN %in% hp$FIN, ]
  if(dim(olog)[1] > 0){
    olog$assessmentDate <- as.Date(format(
                                     as.POSIXct(olog$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }
  
  ## Agitated Behavior Scale query
  if(uc == 0 || demo == 1){
    # absList <- vector('list', nrow(hp))
    # for(i in 1:length(absList)){
    #   absList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, shortattentionspan, impulsive, uncooperative,
    #              repetitive, assessmentdate
    #       FROM outcomedm.abs_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON abs_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # abs <- do.call('rbind', absList)
    absQuery <- paste("
      SELECT mrn, fin_mrn.fin, shortattentionspan, impulsive, uncooperative,
             repetitive, assessmentdate
      FROM outcomedm.abs_frmt
      INNER JOIN outcomedm.fin_mrn
        ON abs_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    abs <- dbGetQuery(awsCon, absQuery)
  }else{
    abs <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_abs_frmt'
    )
  }
  colnames(abs) <- c('MRN', 'FIN', 'shortAttentionSpan', 'impulsive',
                     'uncooperative', 'repetitive', 'assessmentDate'
  )
  abs <- abs[abs$FIN %in% hp$FIN, ]
  if(dim(abs)[1] > 0){
    abs$assessmentDate <- as.Date(format(
                                    as.POSIXct(abs$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }
  
  ## RIC Evaluation of Communication Problems in Right Hemisphere Dysfunction
  ## query
  if(uc == 0 || demo == 1){
    # ric3List <- vector('list', nrow(hp))
    # for(i in 1:length(ric3List)){
    #   ric3List[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, behavioralseverity, pragmaticseverity,
    #              assessmentdate
    #       FROM outcomedm.rice3_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON outcomedm.rice3_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # ric3 <- do.call('rbind', ric3List)
    ric3Query <- paste("
      SELECT mrn, fin_mrn.fin, behavioralseverity, pragmaticseverity,
             assessmentdate
      FROM outcomedm.rice3_frmt
      INNER JOIN outcomedm.fin_mrn
        ON outcomedm.rice3_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    ric3 <- dbGetQuery(awsCon, ric3Query)
  }else{
    ric3 <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_rice3_frmt'
    )
  }
  colnames(ric3) <- c('MRN', 'FIN', 'behavioralSeverity', 'pragmaticSeverity',
                      'assessmentDate'
  )
  ric3 <- ric3[ric3$FIN %in% hp$FIN, ]
  if(dim(ric3)[1] > 0){
    ric3$assessmentDate <- as.Date(format(
                                     as.POSIXct(ric3$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }
  
  ## Three Word Recall query
  if(uc == 0 || demo == 1){
    # twrList <- vector('list', nrow(hp))
    # for(i in 1:length(twrList)){
    #   twrList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, score, assessmentdate
    #       FROM outcomedm.threeword_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON threeword_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # twr <- do.call('rbind', twrList)
    twrQuery <- paste("
      SELECT mrn, fin_mrn.fin, score, assessmentdate
      FROM outcomedm.threeword_frmt
      INNER JOIN outcomedm.fin_mrn
        ON threeword_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    twr <- dbGetQuery(awsCon, twrQuery)
  }else{
    twr <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_threeword_frmt'
    )
  }
  colnames(twr) <- c('MRN', 'FIN', 'score', 'assessmentDate')
  twr <- twr[twr$FIN %in% hp$FIN, ]
  if(dim(twr)[1] > 0){
    twr$assessmentDate <- as.Date(format(
                                    as.POSIXct(twr$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }
  
  ## Rivermead Behavioral Memory Test query
  if(uc == 0 || demo == 1){
    # rvmdList <- vector('list', nrow(hp))
    # for(i in 1:length(rvmdList)){
    #   rvmdList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, storyimmediateraw, storydelayedraw, assessmentdate
    #       FROM outcomedm.rivermead_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON rivermead_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # rvmd <- do.call('rbind', rvmdList)
    rvmdQuery <- paste("
      SELECT mrn, fin_mrn.fin, storyimmediateraw, storydelayedraw, assessmentdate
      FROM outcomedm.rivermead_frmt
      INNER JOIN outcomedm.fin_mrn
        ON rivermead_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    rvmd <- dbGetQuery(awsCon, rvmdQuery)
  }else{
    rvmd <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_rivermead_frmt'
    )
  }
  colnames(rvmd) <- c('MRN', 'FIN', 'storyImmediateRaw', 'storyDelayedRaw',
                      'assessmentDate'
  )
  rvmd <- rvmd[rvmd$FIN %in% hp$FIN, ]
  if(dim(rvmd)[1] > 0){
    rvmd$assessmentDate <- as.Date(format(
                                     as.POSIXct(rvmd$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }
  
  ## Assessment of Intelligibility in Dysarthric Speech query
  if(uc == 0 || demo == 1){
    # aidsList <- vector('list', nrow(hp))
    # for(i in 1:length(aidsList)){
    #   aidsList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, shortnumberofintelligiblewords,
    #              shortintelligiblewordsinsentences, assessmentdate
    #       FROM outcomedm.aids_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON aids_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # aids <- do.call('rbind', aidsList)
    aidsQuery <- paste("
      SELECT mrn, fin_mrn.fin, shortnumberofintelligiblewords,
             shortintelligiblewordsinsentences, assessmentdate
      FROM outcomedm.aids_frmt
      INNER JOIN outcomedm.fin_mrn
        ON aids_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    aids <- dbGetQuery(awsCon, aidsQuery)
  }else{
    aids <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_aids_frmt'
    )
  }
  colnames(aids) <- c('MRN', 'FIN', 'shortNumberOfIntelligibleWords',
                      'shortIntelligibleWordsInSentences', 'assessmentDate'
  )
  aids <- aids[aids$FIN %in% hp$FIN, ]
  if(dim(aids)[1] > 0){
    aids$assessmentDate <- as.Date(format(
                                     as.POSIXct(aids$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago',
                                     '%Y-%m-%d'
                                   )
    )
  }
  
  ## Voice Measures query
  if(uc == 0 || demo == 1){
    # vmList <- vector('list', nrow(hp))
    # for(i in 1:length(vmList)){
    #   vmList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, sustainedphonationtrial1,
    #              sustainedphonationtrial2, sustainedphonationtrial3,
    #              vocalintensitytrial1, vocalintensitytrial2, vocalintensitytrial3,
    #              assessmentdate
    #       FROM outcomedm.voicemeasures_frmt
    #       INNER JOIN outcomedm.FIN_MRN
    #         ON voiceMeasures_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # vm <- do.call('rbind', vmList)
    vmQuery <- paste("
      SELECT mrn, fin_mrn.fin, sustainedphonationtrial1,
             sustainedphonationtrial2, sustainedphonationtrial3,
             vocalintensitytrial1, vocalintensitytrial2, vocalintensitytrial3,
             assessmentdate
      FROM outcomedm.voicemeasures_frmt
      INNER JOIN outcomedm.FIN_MRN
        ON voiceMeasures_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    vm <- dbGetQuery(awsCon, vmQuery)
  }else{
    vm <- dbGetQuery(awsCon, 'SELECT *
                              FROM outcomedm.current_voicemeasures_frmt'
    )
  }
  colnames(vm) <- c('MRN', 'FIN', 'sustainedPhonationTrail1',
                    'sustainedPhonationTrial2', 'sustainedPhonationTrial3',
                    'vocalIntensityTrial1', 'vocalIntensityTrial2',
                    'vocalIntensityTrial3','assessmentDate'
  )
  vm <- vm[vm$FIN %in% hp$FIN, ]
  if(dim(vm)[1] > 0){
    vm$assessmentDate <- as.Date(format(
                                   as.POSIXct(vm$assessmentDate, 'GMT'),
                                   tz = 'America/Chicago',
                                   '%Y-%m-%d'
                                 )
    )
  }
  
  ## Boston Diagnostic Aphasia Examination query
  if(uc == 0 || demo == 1){
    # bdaeList <- vector('list', nrow(hp))
    # for(i in 1:length(bdaeList)){
    #   bdaeList[[i]] <- dbGetQuery(awsCon,
    #     bdaeQuery <- paste("
    #       SELECT mrn, fin_mrn.fin, basicworddiscshort, commandsshort,
    #              complexideationalshort, wordrepetitionshort,
    #              sentencerepetitionshort, specialcategoriesshort, formshort,
    #              letterchoiceshort, motorfacilityshort, picturewordmatchingshort,
    #              oralwordreadingshort, oralsentencereadingshort,
    #              oralsentencecomprehensionshort, sentenceparagraphcomprehensionshort,
    #              assessmentdate
    #       FROM outcomedm.bdae_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON outcomedm.bdae_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # bdae <- do.call('rbind', bdaeList)
    bdaeQuery <- paste("
      SELECT mrn, fin_mrn.fin, basicworddiscshort, commandsshort,
             complexideationalshort, wordrepetitionshort,
             sentencerepetitionshort, specialcategoriesshort, formshort,
             letterchoiceshort, motorfacilityshort, picturewordmatchingshort,
             oralwordreadingshort, oralsentencereadingshort,
             oralsentencecomprehensionshort, sentenceparagraphcomprehensionshort,
             assessmentdate
      FROM outcomedm.bdae_frmt
      INNER JOIN outcomedm.fin_mrn
        ON outcomedm.bdae_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    bdae <- dbGetQuery(awsCon, bdaeQuery)
  }else{
    bdae <- dbGetQuery(awsCon, 'SELECT *
                                FROM outcomedm.current_bdae_frmt'
    )
  }
  colnames(bdae) <- c('MRN', 'FIN', 'basicWordDiscShort', 'commandsShort',
                      'complexIdeationalShort', 'wordRepetitionShort',
                      'sentenceRepetitionShort', 'specialCategoriesShort',
                      'formShort', 'letterChoiceShort', 'motorFacilityShort',
                      'pictureWordMatchingShort', 'oralWordReadingShort',
                      'oralSentenceReadingShort',
                      'oralSentenceComprehensionShort',
                      'sentenceParagraphComprehensionShort', 'assessmentDate'
  )
  bdae <- bdae[bdae$FIN %in% hp$FIN, ]
  if(dim(bdae)[1] > 0){
    bdae$assessmentDate <- as.Date(format(
                                     as.POSIXct(bdae$assessmentDate, 'GMT'),
                                     tz = 'America/Chicago', '%Y-%m-%d'
                                   )
    )
  }
  
  ## Boston Naming Test query
  if(uc == 0 || demo == 1){
    # bntList <- vector('list', nrow(hp))
    # for(i in 1:length(bntList)){
    #   bntList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, spontaneouslygivencorrect,
    #              correctresponsesfollowing, correctfollowingphonemic, correctchoices,
    #              assessmentdate
    #       FROM outcomedm.bnt_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON bnt_frmt.fin = fin_mrn.fin
    #       WHERE fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # bnt <- do.call('rbind', bntList)
    bntQuery <- paste("
      SELECT mrn, fin_mrn.fin, spontaneouslygivencorrect,
             correctresponsesfollowing, correctfollowingphonemic, correctchoices,
             assessmentdate
      FROM outcomedm.bnt_frmt
      INNER JOIN outcomedm.fin_mrn
        ON bnt_frmt.fin = fin_mrn.fin
      WHERE fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    bnt <- dbGetQuery(awsCon, bntQuery)
  }else{
    bnt <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_bnt_frmt'
    )
  }
  colnames(bnt) <- c('MRN', 'FIN', 'spontaneouslyGivenCorrect',
                     'correctResponsesFollowing', 'correctFollowingPhonemic',
                     'correctChoices', 'assessmentDate'
  )
  bnt <- bnt[bnt$FIN %in% hp$FIN, ]
  if(dim(bnt)[1] > 0){
    bnt$assessmentDate <- as.Date(format(
                                    as.POSIXct(bnt$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
    )
  }
  
  ## Functional Independence Measure query
  if(uc == 0 || demo == 1){
    # fimList <- vector('list', nrow(hp))
    # for(i in 1:length(fimList)){
    #   fimList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT mrn, fin_mrn.fin, eating, grooming, bathing, dressingupper,
    #              dressinglower, toileting, bedchairtransfer, tubshowertransfer,
    #              toilettransfer, locomotionwalk, locomotionwheelchair,
    #              locomotionstairs, comprehension, expression, socialinteraction,
    #              problemsolving, memory, transferbedtofromchair,
    #              ambulationlevelsurfaces, wheelchairmobilitylevelsurfaces,
    #              stairsambulationassist, ambulationdistance,
    #              wheelchairmobilityleveldistance, numberofstairsperformed,
    #              assessmentdate, assessedby, formnm
    #       FROM outcomedm.fimprimary_frmt
    #       INNER JOIN outcomedm.fin_mrn
    #         ON fimprimary_frmt.fin = fin_mrn.fin
    #       WHERE formcd NOT IN
    #             ('1017469961', '13085869', '2700569', '1047648943', '13117692',
    #              '4134981', '4331538'
    #             )
    #         AND fin_mrn.fin = '", as.numeric(hp$FIN[i]), "';", sep = '')
    #   )
    # }
    # fim <- do.call('rbind', fimList)
    fimQuery <- paste("
      SELECT mrn, fin_mrn.fin, eating, grooming, bathing, dressingupper,
             dressinglower, toileting, bedchairtransfer, tubshowertransfer,
             toilettransfer, locomotionwalk, locomotionwheelchair,
             locomotionstairs, comprehension, expression, socialinteraction,
             problemsolving, memory, transferbedtofromchair,
             ambulationlevelsurfaces, wheelchairmobilitylevelsurfaces,
             stairsambulationassist, ambulationdistance,
             wheelchairmobilityleveldistance, numberofstairsperformed,
             assessmentdate, assessedby, formnm
      FROM outcomedm.fimprimary_frmt
      INNER JOIN outcomedm.fin_mrn
        ON fimprimary_frmt.fin = fin_mrn.fin
      WHERE formcd NOT IN
            ('1017469961', '13085869', '2700569', '1047648943', '13117692',
             '4134981', '4331538'
            )
        AND fin_mrn.fin IN (\'", paste(hp$FIN,
                                       collapse = "\', \'"
                                 ), '\');', sep = ''
    )
    fim <- dbGetQuery(awsCon, fimQuery)
  }else{
    fim <- dbGetQuery(awsCon, 'SELECT *
                               FROM outcomedm.current_fimprimary_frmt'
    )
  }
  colnames(fim) <- c('MRN', 'FIN', 'eating', 'grooming', 'bathing',
                     'dressingUpper', 'dressingLower', 'toileting',
                     'bedChairTransfer', 'tubShowerTransfer', 'toiletTransfer',
                     'locomotionWalk', 'locomotionWheelchair',
                     'locomotionStairs', 'comprehension', 'expression',
                     'socialInteraction', 'problemSolving', 'memory',
                     'bedChairTransfer2',  'locomotionWalk2',
                     'locomotionWheelchair2', 'locomotionStairs2', 'walkDist',
                     'wheelDist', 'numStairs', 'assessmentDate', 'assessedBy',
                     'form'
  )
  fim <- fim[which(!(fim$form %in% c('Nursing Admit FIM/QI',
                                     'Pre-Admission Data Form',
                                     'Art and Music Therapy Evaluation',
                                     'Number of Accidents Form',
                                     'Nursing Discharge FIM/QI'
  ))), ]
  fim <- fim[fim$FIN %in% hp$FIN, ]
  fim <- fim[order(fim$FIN, fim$assessmentDate), ]
  
  ## I was asked to only report OT ratings of tub/shower and toilet transfers.
  ## This code removes the PT ratings for those items. Note that the Team
  ## Conference Form is excluded from this logic; this happens because the EDW
  ## only contains the first person who signed off on that form in the
  ## assessedby field, making it impossible to determine who recorded that
  ## information. Chances are, however, that it was an OT.
  fimSplit <- split(fim, paste(fim$FIN))
  for(i in 1:length(fimSplit)){
    fimFIN <- as.data.frame(fimSplit[i])
    colnames(fimFIN) <- colnames(fim)
    pt_tt <- intersect(intersect(grep(' PT', fim$assessedBy),
                                 which(!is.na(fim$toiletTransfer))
                       ),
                       which(fim$form != 'Team Conference Form')
    )
    ot_tt <- intersect(intersect(grep(' OT', fim$assessedBy),
                                 which(!is.na(fim$toiletTransfer))
                       ),
                       which(fim$form != 'Team Conference Form')
    )
    if(length(pt_tt) > 0){
      if(length(ot_tt) > 0 && any(pt_tt < min(ot_tt))){
        fim$toiletTransfer[pt_tt[pt_tt > min(ot_tt)]] <- NA
      }else if(length(ot_tt) > 0 && all(pt_tt > min(ot_tt))){
        fim$toiletTransfer[pt_tt] <- NA
      }
    }
    pt_tst <- intersect(intersect(grep(' PT', fim$assessedBy),
                                  which(!is.na(fim$tubShowerTransfer))
                        ),
                        which(fim$form != 'Team Conference Form')
    )
    ot_tst <- intersect(intersect(grep(' OT', fim$assessedBy),
                                  which(!is.na(fim$toiletTransfer))
                       ),
                       which(fim$form != 'Team Conference Form')
    )
    if(length(pt_tst) > 0){
      if(length(ot_tst) > 0 && any(pt_tst < min(ot_tst))){
        fim$toiletTransfer[pt_tst[pt_tst > min(ot_tst)]] <- NA
      }else if(length(ot_tst) > 0 && all(pt_tst > min(ot_tst))){
        fim$toiletTransfer[pt_tst] <- NA
      }
    }
  
    ## Similar to the above logic, but for OT and the FIM's cognition items. Only
    ## SLP ratings should be included for those items.
    ot_comp <- intersect(intersect(grep(' OT', fim$assessedBy),
                                   which(!is.na(fim$comprehension))
                         ),
                         which(fim$form != 'Team Conference Form')
    )
    slp_comp <- intersect(
                  intersect(unique(
                              c(grep(' SLP', fim$assessedBy),
                                grep(' CCC-SLP', fim$assessedBy)
                              )
                            ),
                            which(!is.na(fim$comprehension))
                  ),
                  which(fim$form != 'Team Conference Form')
    )
    if(length(ot_comp) > 0){
      if(length(slp_comp) > 0 && any(ot_comp < min(slp_comp))){
        fim$comprehension[ot_comp[ot_comp > min(slp_comp)]] <- NA
      }else if(length(slp_comp) > 0 && all(ot_comp > min(slp_comp))){
        fim$comprehension[ot_comp] <- NA
      }
    }
    ot_exp <- intersect(intersect(grep(' OT', fim$assessedBy),
                                  which(!is.na(fim$expression))
                        ),
                        which(fim$form != 'Team Conference Form')
    )
    slp_exp <- intersect(
                  intersect(unique(
                              c(grep(' SLP', fim$assessedBy),
                                grep(' CCC-SLP', fim$assessedBy)
                              )
                            ),
                            which(!is.na(fim$expression))
                  ),
                  which(fim$form != 'Team Conference Form')
    )
    if(length(ot_exp) > 0){
      if(length(slp_exp) > 0 && any(ot_exp < min(slp_exp))){
        fim$expression[ot_exp[ot_exp > min(slp_exp)]] <- NA
      }else if(length(slp_exp) > 0 && all(ot_exp > min(slp_exp))){
        fim$expression[ot_exp] <- NA
      }
    }
    ot_si <- intersect(intersect(
                         grep(' OT', fim$assessedBy),
                         which(!is.na(fim$socialInteraction))
                       ),
                       which(fim$form != 'Team Conference Form')
    )
    slp_si <- intersect(
                  intersect(unique(
                              c(grep(' SLP', fim$assessedBy),
                                grep(' CCC-SLP', fim$assessedBy)
                              )
                            ),
                            which(!is.na(fim$socialInteraction))
                  ),
                  which(fim$form != 'Team Conference Form')
    )
    if(length(ot_si) > 0){
      if(length(slp_si) > 0 && any(ot_si < min(slp_si))){
        fim$socialInteraction[ot_si[ot_si > min(slp_si)]] <- NA
      }else if(length(slp_si) > 0 && all(ot_si > min(slp_si))){
        fim$socialInteraction[ot_si] <- NA
      }
    }
    ot_ps <- intersect(intersect(grep(' OT', fim$assessedBy),
                                   which(!is.na(fim$problemSolving))
                         ),
                         which(fim$form != 'Team Conference Form')
    )
    slp_ps <- intersect(
                  intersect(unique(
                              c(grep(' SLP', fim$assessedBy),
                                grep(' CCC-SLP', fim$assessedBy)
                              )
                            ),
                            which(!is.na(fim$problemSolving))
                  ),
                  which(fim$form != 'Team Conference Form')
    )
    if(length(ot_ps) > 0){
      if(length(slp_ps) > 0 && any(ot_ps < min(slp_ps))){
        fim$problemSolving[ot_ps[ot_ps > min(slp_ps)]] <- NA
      }else if(length(slp_ps) > 0 && all(ot_ps > min(slp_ps))){
        fim$problemSolving[ot_ps] <- NA
      }
    }
    ot_mem <- intersect(intersect(grep(' OT', fim$assessedBy),
                                   which(!is.na(fim$memory))
                         ),
                         which(fim$form != 'Team Conference Form')
    )
    slp_mem <- intersect(
                  intersect(unique(
                              c(grep(' SLP', fim$assessedBy),
                                grep(' CCC-SLP', fim$assessedBy)
                              )
                            ),
                            which(!is.na(fim$memory))
                  ),
                  which(fim$form != 'Team Conference Form')
    )
    if(length(ot_mem) > 0){
      if(length(slp_mem) > 0 && any(ot_mem < min(slp_mem))){
        fim$memory[ot_mem[ot_mem > min(slp_mem)]] <- NA
      }else if(length(slp_mem) > 0 && all(ot_mem > min(slp_mem))){
        fim$memory[ot_mem] <- NA
      }
    }
    fimFIN <- split(fimFIN, paste(fimFIN$FIN))
    fimSplit <- replace(fimSplit, i, fimFIN)
  }
  
  fim <- do.call('rbind', fimSplit)
  
  ## Drops the assessedBy and form columns as they are no longer needed.
  fim <- fim[, -c(28:29)]
  
  ## This loop performs a plethora of formatting and rescoring logic to
  ## accommodate the quirks of FIM data pulled from Cerner. See mark-up for
  ## more information.
  
  ## This conditional prevents the dashboard from crashing if no FIM data are
  ## recorded (usually occurs when the table is being updated on the EDW).
  if(nrow(fim) > 1){
    ## Split the fim data.frame into a list of data.frames by FIN
    fimSplit <- split(fim, paste(fim$FIN))
    ## Loop over unique patients...
    for(i in 1:length(fimSplit)){
      ## Because fimSplit is a list object, we convert it to a data.frame to
      ## make it much easier to work with
      fimFIN <- as.data.frame(fimSplit[i])
      colnames(fimFIN) <- colnames(fim)
      fimFIN <- fimFIN[order(fimFIN$assessmentDate), ]
      ## Because numStairs is a free-entry text field on the Cerner form, this
      ## will probably require special attention or process changes down the
      ## road.
      fimFIN$numStairs <- as.numeric(fimFIN$numStairs)
      ## Helpful variables for indicating (with a 1) that the patient is not
      ## capable of reaching certain criteria for distance or number of stairs
      ## climbed.
      walkCheck150 <- sapply(fimFIN$walkDist,
                             function(x) ifelse(x >= 150, 0, 1)
      )
      walkCheck50 <- sapply(fimFIN$walkDist,
                            function(x) ifelse(x >= 50, 0, 1)
      )
      wheelCheck150 <- sapply(fimFIN$wheelDist,
                              function(x) ifelse(x >= 150, 0, 1)
      )
      wheelCheck50 <- sapply(fimFIN$wheelDist,
                             function(x) ifelse(x >= 50, 0, 1)
      )
      stairsCheck12 <- sapply(fimFIN$numStairs,
                              function(x) ifelse(x >= 12, 0, 1)
      )
      stairsCheck4 <- sapply(fimFIN$numStairs,
                             function(x) ifelse(x >= 4, 0, 1)
      )
      ## Loop over assessment instances
      for(j in 1:nrow(fimFIN)){
        ## If the value of the indicator variable isn't missing and the FIM
        ## rating is neither missing nor "Does not occur"...
        if(!is.na(walkCheck50[j]) &&
           !(fimFIN$locomotionWalk2[j] %in% c(88, NA))
        ){
          ## If the patient cannot ambulate 50ft. and their assistance level
          ## has been rated higher than "Total Dependence," then change the
          ## rating to "1 - Total Dependence"
          if(walkCheck50[j] == 1 && fimFIN$locomotionWalk2[j] > 1){
            fimFIN$locomotionWalk2[j] <- 1
          ## Otherwise, if the patient can walk between 50ft. and 150ft. and
          ## their assistance level is greater than "Supervision," change the
          ## rating to "5 - Supervision"
          }else if(walkCheck50[j] == 0 &&
                   walkCheck150[j] == 1 &&
                   fimFIN$locomotionWalk2[j] > 5
          ){
            fimFIN$locomotionWalk2[j] <- 5
          ## Otherwise, if the patient walks between 50ft. and 150ft. and has
          ## been rated higher than "Max Assistance," change the rating to
          ## "2 - Max Assistance"
          }else if(walkCheck50[j] == 0 &&
                   walkCheck150[j] == 1 &&
                   fimFIN$locomotionWalk2[j] > 2
          ){
            fimFIN$locomotionWalk2[j] <- 2
          }
          ## Otherwise, just leave the rating alone
        }
        ## This is the same logic as above, but applied to wheelchair
        ## locomotion. The 50ft. and 150ft. criteria are the same
        if(!is.na(wheelCheck50[j]) &&
           !(fimFIN$locomotionWheelchair2[j] %in% c(88, NA))
        ){
          if(wheelCheck50[j] == 1 && fimFIN$locomotionWheelchair2[j] > 1){
            fimFIN$locomotionWheelchair2[j] <- 1
          }else if(wheelCheck50[j] == 0 &&
                   wheelCheck150[j] == 1 &&
                   fimFIN$locomotionWheelchair2[j] > 5
          ){
            fimFIN$locomotionWheelchair2[j] <- 5
          }else if(wheelCheck50[j] == 0 &&
                   wheelCheck150[j] == 1 &&
                   fimFIN$locomotionWheelchair2[j] > 2
          ){
            fimFIN$locomotionWheelchair2[j] <- 2
          }
        }
        ## Once again, a bit of a repeat, but this time for locomotion on
        ## stairs. Replace "4 steps" for "50ft." and "12 steps" for "150 ft.",
        ## and it's basically the same deal.
        if(!is.na(stairsCheck4[j]) &&
           !(fimFIN$locomotionStairs2[j] %in% c(88, NA))
        ){
          if(stairsCheck4[j] == 1 && fimFIN$locomotionStairs2[j] > 1){
            fimFIN$locomotionStairs2[j] <- 1
          }else if(stairsCheck4[j] == 0 &&
                   stairsCheck12[j] == 1 &&
                   fimFIN$locomotionStairs2[j] > 5
          ){
            fimFIN$locomotionStairs2[j] <- 5
          }else if(stairsCheck4[j] == 0 &&
                   stairsCheck12[j] == 1 &&
                   fimFIN$locomotionStairs2[j] > 2
          ){
            fimFIN$locomotionStairs2[j] <- 2
          }
        }
      }
      ## Performs a split based on date.
      fimSplit2 <- split(fimFIN, 
                         paste(as.Date(format(
                                         as.POSIXct(fimFIN$assessmentDate,
                                                    'GMT'
                                         ),
                                         tz = 'America/Chicago',
                                         '%Y-%m-%d'
                                       )
                         ))
      )
      ## Drops empty elements of the list, which can happen in some cases of
      ## all-missing data.
      fimSplit2 <- fimSplit2[sapply(fimSplit2, function(x) dim(x)[1] > 0)]
      ## Loop over assessement dates. Note that this is slightly different than
      ## the above j-indexed loop. In each iteration of that loop, every
      ## assessment instance was considered (i.e., there can be multiple FIM
      ## assessments per day). In this case, we're collapsing multiple FIM
      ## assessments into the same date. FIM reporting usually covers the
      ## minumum rating of each item per day, and we want to mimic that here.
      for(j in 1:length(fimSplit2)){
        ## Convert to data.frame
        fimAD <- as.data.frame(fimSplit2[j])
        colnames(fimAD) <- colnames(fim)
        ## Loop over assessments within each assessment day.
        for(k in 1:nrow(fimAD)){
          ## With Team Conference Forms and PT Daily Notes, it's often the case
          ## that an assistance level and criterion value (distance walked,
          ## distance wheeled, or number of stairs) will be reported. While
          ## nice, it's not an actual FIM rating. Now that we've converted
          ## those values into FIM ratings above, this will overwrite the
          ## missing values or "does not occur" entries that often wind up
          ## in the field where the corresponding FIM rating should be.
          fimAD$bedChairTransfer[k] <- ifelse(is.na(fimAD$bedChairTransfer[k]),
                                              fimAD$bedChairTransfer2[k],
                                              fimAD$bedChairTransfer[k]
          )
          fimAD$locomotionWalk[k] <- ifelse(is.na(fimAD$locomotionWalk[k]),
                                            fimAD$locomotionWalk2[k],
                                            fimAD$locomotionWalk[k]
          )
          fimAD$locomotionWheelchair[k] <- ifelse(
                                             is.na(
                                               fimAD$locomotionWheelchair[k]
                                             ),
                                             fimAD$locomotionWheelchair2[k],
                                             fimAD$locomotionWheelchair[k]
          )
          fimAD$locomotionStairs[k] <- ifelse(is.na(fimAD$locomotionStairs[k]),
                                              fimAD$locomotionStairs2[k],
                                              fimAD$locomotionStairs[k]
          )
          fimAD$bedChairTransfer[k] <- ifelse(
                                         (fimAD$bedChairTransfer[k] %in% 88) &&
                                         !is.na(fimAD$bedChairTransfer2[k]),
                                         fimAD$bedChairTransfer2[k],
                                         fimAD$bedChairTransfer[k]
          )
          fimAD$locomotionWalk[k] <- ifelse(
                                       (fimAD$locomotionWalk[k] %in% 88) &&
                                       !is.na(fimAD$locomotionWalk2[k]),
                                       fimAD$locomotionWalk2[k],
                                       fimAD$locomotionWalk[k]
          )
          fimAD$locomotionWheelchair[k] <- ifelse(
            (fimAD$locomotionWheelchair[k] %in% 88) &&
            !is.na(fimAD$locomotionWheelchair2[k]),
            fimAD$locomotionWheelchair2[k],
            fimAD$locomotionWheelchair[k]
          )
          fimAD$locomotionStairs[k] <- ifelse(
                                         (fimAD$locomotionStairs[k] %in% 88) &&
                                         !is.na(fimAD$locomotionStairs2[k]),
                                         fimAD$locomotionStairs2[k],
                                         fimAD$locomotionStairs[k]
          )
        }
        ## Now that the proper values are recorded in the columns we'll be
        ## keeping, we can drop the columns we won't be using.
        fimAD <- fimAD[, -c(20:26)]
        ## Run repeat.before2 on each assessment date. We want to prioritize
        ## the most recent non-missing, non-"does not occur" value we have
        ## access to.
        fimAD[, 3:19] <- apply(fimAD[, 3:19], 2,
                              function(x) repeat.before2(x, 88)
        )
        ## Puts the modified and formatted data back into the list object
        fimAD <- split(fimAD, paste(fimAD$FIN))
        fimSplit2 <- replace(fimSplit2, j, fimAD)
      }
      ## With the "keeper" data now in the last row of every element of the
      ## list of data.frames, take the last row of each date-specific
      ## data.frame.
      fimSplit2 <- lapply(fimSplit2, function(x) tail(x, 1))
      ## Compress the list back into a data.frame
      fimFIN <- do.call('rbind', fimSplit2)
      ## This isn't totally necessary, but ensures that the most recent
      ## non-"does not occur" values are always reported on the dashboard. It
      ## is very convenient to do this here rather than in every other place
      ## it would have to happen.
      fimFIN[, 3:19] <- apply(fimFIN[, 3:19], 2,
                              function(x) repeat.before2(x, 88)
      )
      ## Replace the old list entry with the now correct data.frame we just
      ## made.
      fimFIN <- split(fimFIN, paste(fimFIN$FIN))
      fimSplit <- replace(fimSplit, i, fimFIN)
    }
    ## Compress the whole thing back into the fim data.frame.
    fim <- do.call('rbind', fimSplit)
  }

  ## Now we can convert the date/times into dates like the other AQ measures.
  if(dim(fim)[1] > 0){
    fim$assessmentDate <- as.Date(format(
                                    as.POSIXct(fim$assessmentDate, 'GMT'),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d H:M:S'
                                  )
    )
    fim <- fim[order(fim$FIN, fim$assessmentDate), ]
  }
  ## Split fim into the self-care, mobility, and cognition forms, or, if all
  ## the FIM data are missing, just make a 
  if(nrow(fim) > 1){
    fimSC <- fim[, c(1:8, 20)]
    fimMob <- fim[, c(1:2, 9:14, 20)]
    fimCog <- fim[, c(1:2, 15:20)]
  }else{
    fimSC <- data.frame(MRN = NA, FIN = NA, eating = NA, grooming = NA,
                        bathing = NA, dressingUpper = NA, dressingLower = NA,
                        toileting = NA, assessmentDate = NA
    )
    fimMob <- data.frame(MRN = NA, FIN = NA, bedChairTransfer = NA,
                         tubShowerTransfer = NA, toiletTransfer = NA,
                         locomotionWalk = NA, locomotionWheelchair = NA,
                         locomotionStairs = NA, assessmentDate = NA
    )
    fimCog <- data.frame(MRN = NA, FIN = NA, comprehension = NA,
                         expression = NA, socialInteraction = NA,
                         problemSolving = NA, memory = NA, assessmentDate = NA
    )
  }
  
  ## FIM Goals query
  if(uc == 0 || demo == 1){
    # fimGoalsList <- vector('list', nrow(hp))
    # for(i in 1:length(fimGoalsList)){
    #   fimGoalsList[[i]] <- dbGetQuery(awsCon,
    #     paste("
    #       SELECT fin, assessmentdate, fim_eating_goal, fim_grooming_goal,
    #              fim_bathing_goal, fim_ue_dressing_goal, fim_le_dressing_goal,
    #              fim_toileting_goal, fim_bed_chair_transfer_goal,
    #              fim_tub_shower_transfer_goal, fim_toilet_transfer_goal,
    #              fim_ambulation_goal, fim_wheelchair_mobility_goal,
    #              fim_stairs_ambulation_goal, fim_comprehension_goal,
    #              fim_expression_goal, fim_social_interaction_goal,
    #              fim_problem_solving_goal, fim_memory_goal,
    #              fim_mode_of_locomotion_goal, assessedby, formnm
    #       FROM outcomedm.fim_goals_frmt
    #       WHERE outcomedm.fim_goals_frmt.fin = '", as.numeric(hp$FIN[i]), "';", sep = ''
    #     )
    #   )
    # }
    # fimGoals <- do.call('rbind', fimGoalsList)
    fimGoalsQuery <- paste("
      SELECT fin, assessmentdate, fim_eating_goal, fim_grooming_goal,
             fim_bathing_goal, fim_ue_dressing_goal, fim_le_dressing_goal,
             fim_toileting_goal, fim_bed_chair_transfer_goal,
             fim_tub_shower_transfer_goal, fim_toilet_transfer_goal,
             fim_ambulation_goal, fim_wheelchair_mobility_goal,
             fim_stairs_ambulation_goal, fim_comprehension_goal,
             fim_expression_goal, fim_social_interaction_goal,
             fim_problem_solving_goal, fim_memory_goal,
             fim_mode_of_locomotion_goal, assessedby, formnm
      FROM outcomedm.fim_goals_frmt
      WHERE outcomedm.fim_goals_frmt.fin IN (\'", paste(hp$FIN,
                                                        collapse = "\', \'"
                                                  ), '\');', sep = ''
    )
    fimGoals <- dbGetQuery(awsCon, fimGoalsQuery)
  }else{
    fimGoals <- dbGetQuery(awsCon, 'SELECT *
                                    FROM outcomedm.current_fim_goals_frmt'
    )
  }
  colnames(fimGoals) <- c('FIN', 'assessmentDate', 'eating', 'grooming',
                          'bathing', 'dressingUpper', 'dressingLower',
                          'toileting', 'bedChairTransfer', 
                          'tubShowerTransfer', 'toiletTransfer',
                          'locomotionWalk','locomotionWheelchair',
                          'locomotionStairs','comprehension', 'expression',
                          'socialInteraction','problemSolving', 'memory',
                          'molGoal', 'assessedBy', 'form'
  )
  fimGoals <- fimGoals[fimGoals$FIN %in% hp$FIN, ]
  fimGoalCheck <- which(Reduce(`&`, as.data.frame(is.na(fimGoals[, 3:19]))))
  if(length(fimGoalCheck) > 0){
    fimGoals <- fimGoals[-fimGoalCheck, ]
    fimGoals <- fimGoals[order(fimGoals$FIN, fimGoals$assessmentDate), ]
  }
  
  ## This loop, in essence, merely ensures that the most recent values flow
  ## downward (both within and between dates). Also provides priority for
  ## certain items in the same manner as the FIM
  if(nrow(fimGoals) > 1){
    fimGoalsSplit <- split(fimGoals, paste(fimGoals$FIN))
    for(i in 1:length(fimGoalsSplit)){
      fimGoalsFIN <- as.data.frame(fimGoalsSplit[i])
      colnames(fimGoalsFIN) <- colnames(fimGoals)
      ## Similar logic to the FIM scores; drop PT goals for tub/shower and
      ## toilet transfers as well as OT goals for Cog items.
      pt_tt <- intersect(intersect(grep(' PT', fimGoalsFIN$assessedBy),
                                   which(!is.na(fimGoalsFIN$toiletTransfer))
                         ),
                         which(fimGoalsFIN$form != 'Team Conference Form')
      )
      ot_tt <- intersect(intersect(grep(' OT', fimGoalsFIN$assessedBy),
                                   which(!is.na(fimGoalsFIN$toiletTransfer))
                         ),
                         which(fimGoalsFIN$form != 'Team Conference Form')
      )
      if(length(pt_tt) > 0){
        if(length(ot_tt) > 0 && any(pt_tt < min(ot_tt))){
          fimGoalsFIN$toiletTransfer[pt_tt[pt_tt > min(ot_tt)]] <- NA
        }else if(length(ot_tt) > 0 && all(pt_tt > min(ot_tt))){
          fimGoalsFIN$toiletTransfer[pt_tt] <- NA
        }
      }
      pt_tst <- intersect(intersect(grep(' PT', fimGoalsFIN$assessedBy),
                                    which(!is.na(fimGoalsFIN$tubShowerTransfer))
                          ),
                          which(fimGoalsFIN$form != 'Team Conference Form')
      )
      ot_tst <- intersect(intersect(grep(' OT', fimGoalsFIN$assessedBy),
                                    which(!is.na(fimGoalsFIN$toiletTransfer))
                         ),
                         which(fimGoalsFIN$form != 'Team Conference Form')
      )
      if(length(pt_tst) > 0){
        if(length(ot_tst) > 0 && any(pt_tst < min(ot_tst))){
          fimGoalsFIN$toiletTransfer[pt_tst[pt_tst > min(ot_tst)]] <- NA
        }else if(length(ot_tst) > 0 && all(pt_tst > min(ot_tst))){
          fimGoalsFIN$toiletTransfer[pt_tst] <- NA
        }
      }
      ot_comp <- intersect(intersect(grep(' OT', fimGoalsFIN$assessedBy),
                                     which(!is.na(fimGoalsFIN$comprehension))
                           ),
                           which(fimGoalsFIN$form != 'Team Conference Form')
      )
      slp_comp <- intersect(
                    intersect(unique(
                                c(grep(' SLP', fimGoalsFIN$assessedBy),
                                  grep(' CCC-SLP', fimGoalsFIN$assessedBy)
                                )
                              ),
                              which(!is.na(fimGoalsFIN$comprehension))
                    ),
                    which(fimGoalsFIN$form != 'Team Conference Form')
      )
      if(length(ot_comp) > 0){
        if(length(slp_comp) > 0 && any(ot_comp < min(slp_comp))){
          fimGoalsFIN$comprehension[ot_comp[ot_comp > min(slp_comp)]] <- NA
        }else if(length(slp_comp) > 0 && all(ot_comp > min(slp_comp))){
          fimGoalsFIN$comprehension[ot_comp] <- NA
        }
      }
      ot_exp <- intersect(intersect(grep(' OT', fimGoalsFIN$assessedBy),
                                    which(!is.na(fimGoalsFIN$expression))
                          ),
                          which(fimGoalsFIN$form != 'Team Conference Form')
      )
      slp_exp <- intersect(
                    intersect(unique(
                                c(grep(' SLP', fimGoalsFIN$assessedBy),
                                  grep(' CCC-SLP', fimGoalsFIN$assessedBy)
                                )
                              ),
                              which(!is.na(fimGoalsFIN$expression))
                    ),
                    which(fimGoalsFIN$form != 'Team Conference Form')
      )
      if(length(ot_exp) > 0){
        if(length(slp_exp) > 0 && any(ot_exp < min(slp_exp))){
          fimGoalsFIN$expression[ot_exp[ot_exp > min(slp_exp)]] <- NA
        }else if(length(slp_exp) > 0 && all(ot_exp > min(slp_exp))){
          fimGoalsFIN$expression[ot_exp] <- NA
        }
      }
      ot_si <- intersect(intersect(
                           grep(' OT', fimGoalsFIN$assessedBy),
                           which(!is.na(fimGoalsFIN$socialInteraction))
                         ),
                         which(fimGoalsFIN$form != 'Team Conference Form')
      )
      slp_si <- intersect(
                    intersect(unique(
                                c(grep(' SLP', fimGoalsFIN$assessedBy),
                                  grep(' CCC-SLP', fimGoalsFIN$assessedBy)
                                )
                              ),
                              which(!is.na(fimGoalsFIN$socialInteraction))
                    ),
                    which(fimGoalsFIN$form != 'Team Conference Form')
      )
      if(length(ot_si) > 0){
        if(length(slp_si) > 0 && any(ot_si < min(slp_si))){
          fimGoalsFIN$socialInteraction[ot_si[ot_si > min(slp_si)]] <- NA
        }else if(length(slp_si) > 0 && all(ot_si > min(slp_si))){
          fimGoalsFIN$socialInteraction[ot_si] <- NA
        }
      }
      ot_ps <- intersect(intersect(grep(' OT', fimGoalsFIN$assessedBy),
                                     which(!is.na(fimGoalsFIN$problemSolving))
                           ),
                           which(fimGoalsFIN$form != 'Team Conference Form')
      )
      slp_ps <- intersect(
                    intersect(unique(
                                c(grep(' SLP', fimGoalsFIN$assessedBy),
                                  grep(' CCC-SLP', fimGoalsFIN$assessedBy)
                                )
                              ),
                              which(!is.na(fimGoalsFIN$problemSolving))
                    ),
                    which(fimGoalsFIN$form != 'Team Conference Form')
      )
      if(length(ot_ps) > 0){
        if(length(slp_ps) > 0 && any(ot_ps < min(slp_ps))){
          fimGoalsFIN$problemSolving[ot_ps[ot_ps > min(slp_ps)]] <- NA
        }else if(length(slp_ps) > 0 && all(ot_ps > min(slp_ps))){
          fimGoalsFIN$problemSolving[ot_ps] <- NA
        }
      }
      ot_mem <- intersect(intersect(grep(' OT', fimGoalsFIN$assessedBy),
                                     which(!is.na(fimGoalsFIN$memory))
                           ),
                           which(fimGoalsFIN$form != 'Team Conference Form')
      )
      slp_mem <- intersect(
                    intersect(unique(
                                c(grep(' SLP', fimGoalsFIN$assessedBy),
                                  grep(' CCC-SLP', fimGoalsFIN$assessedBy)
                                )
                              ),
                              which(!is.na(fimGoalsFIN$memory))
                    ),
                    which(fimGoalsFIN$form != 'Team Conference Form')
      )
      if(length(ot_mem) > 0){
        if(length(slp_mem) > 0 && any(ot_mem < min(slp_mem))){
          fimGoalsFIN$memory[ot_mem[ot_mem > min(slp_mem)]] <- NA
        }else if(length(slp_mem) > 0 && all(ot_mem > min(slp_mem))){
          fimGoalsFIN$memory[ot_mem] <- NA
        }
      }
      fimGoalsSplit2 <- split(fimGoalsFIN,
                              paste(
                                as.Date(
                                  format(
                                    as.POSIXct(fimGoalsFIN$assessmentDate,
                                               'GMT'
                                    ),
                                    tz = 'America/Chicago',
                                    '%Y-%m-%d'
                                  )
                                )
                              )
      )
      fimGoalsSplit2 <- fimGoalsSplit2[sapply(fimGoalsSplit2,
                                              function(x) dim(x)[1] > 0)
      ]
      for(j in 1:length(fimGoalsSplit2)){
        fimGoalsAD <- as.data.frame(fimGoalsSplit2[j])
        colnames(fimGoalsAD) <- colnames(fimGoals)
        fimGoalsAD <- fimGoalsAD[order(fimGoalsAD$assessmentDate), ]
        fimGoalsAD[, 3:20] <- apply(fimGoalsAD[, 3:20], 2, repeat.before)
        fimGoalsAD <- split(fimGoalsAD, paste(fimGoalsAD$FIN))
        fimGoalsSplit2 <- replace(fimGoalsSplit2, j, fimGoalsAD)
      }
      fimGoalsSplit2 <- lapply(fimGoalsSplit2, function(x) tail(x, 1))
      fimGoalsFIN <- do.call('rbind', fimGoalsSplit2)
      fimGoalsFIN[, 3:20] <- apply(fimGoalsFIN[, 3:20], 2, repeat.before)
      fimGoalsFIN <- split(fimGoalsFIN, paste(fimGoalsFIN$FIN))
      fimGoalsSplit <- replace(fimGoalsSplit, i, fimGoalsFIN)
    }
    fimGoals <- do.call('rbind', fimGoalsSplit)
  }
  
  ## Drop assessedBy and form columns
  fimGoals <- fimGoals[, -c(21:22)]
  
  ## Format the dates
  if(dim(fimGoals)[1] > 0){
    fimGoals$assessmentDate <- as.Date(format(
                                         as.POSIXct(fimGoals$assessmentDate,
                                                    'GMT'
                                         ),
                                         tz = 'America/Chicago',
                                         '%Y-%m-%d'
                                       )
    )
  }
  ## Convert the FIM ratings (but not the mode of locomotion goal) into numeric
  ## type.
  if(nrow(fimGoals) > 1){
    fimGoals[, 3:19] <- apply(fimGoals[, 3:19], 2, as.numeric)
  }
  ## Split into domain-specific data.frames.
  fimSCGoals <- fimGoals[, 1:8]
  fimMobGoals <- fimGoals[, c(1:2, 9:14)]
  fimCogGoals <- fimGoals[, c(1:2, 15:19)]

  ## Isolates and takes the most recent FIM mode of locmotion goal. Note the
  ## seemingly redundant date conversion; this is because splitting and
  ## binding data.frames has an annoying habit of ruining date formatting.
  fimMOL <- fimGoals[, c(1, 2, 20)]
  fimMOL <- fimMOL[!duplicated(fimMOL), ]
  fimMOLSplit <- split(fimMOL, paste(fimMOL$FIN))
  fimMOLSplit <- lapply(fimMOLSplit, function(x) tail(x, 1))
  fimMOL <- do.call('rbind', fimMOLSplit)
  fimMOL$assessmentDate <- as.Date(as.POSIXct(strptime(fimMOL$assessmentDate,
                                                       '%Y-%m-%d'
                                              )
  ))

  ## Speech/Language Pathologist Evaluation query
  if(uc == 0 || demo == 1){
    ## Used for splitting patients into cognitive groups for the AQ. Note that
    ## we no longer use the Oral/Motor diagnosis, but it's still left in here.
    # cogDiagList <- vector('list', nrow(hp))
    # for(i in 1:length(cogDiagList)){
    #   cogDiagList[[i]] <- dbGetQuery(awsCon,
    #     cogDiagQuery <- paste("
    #       SELECT fin, assessmentdate, cognitive_communication_diagnosis,
    #              language_diagnosis, oral_motor_diagnosis, speech_diagnosis,
    #              cognitive_communication_severity, language_severity, speech_severity
    #       FROM outcomedm.slp_eval_frmt
    #       WHERE fin IN (\'", paste(hp$FIN, collapse = "\', \'"), '\');', sep = ''
    #     )
    #   )
    # }
    # cogDiag <- do.call('rbind', cogDiagList)
    cogDiagQuery <- paste("
      SELECT fin, assessmentdate, cognitive_communication_diagnosis,
             language_diagnosis, oral_motor_diagnosis, speech_diagnosis,
             cognitive_communication_severity, language_severity, speech_severity
      FROM outcomedm.slp_eval_frmt
      WHERE fin IN (\'", paste(hp$FIN, collapse = "\', \'"), '\');', sep = ''
    )
    cogDiag <- dbGetQuery(awsCon, cogDiagQuery)
  }else{
    cogDiag <- dbGetQuery(awsCon, 'SELECT *
                                   FROM outcomedm.current_slp_eval_frmt'
    )
  }
  colnames(cogDiag) <- c('FIN', 'assessmentDate', 'cogComD', 'langD', 'orMoD',
                         'speD', 'cogComS', 'langS', 'speS'
  )
  cogDiag <- cogDiag[cogDiag$FIN %in% hp$FIN, ]
  if(dim(cogDiag)[1] > 0){
    cogDiag$assessmentDate <- as.Date(format(
                                        as.POSIXct(cogDiag$assessmentDate,
                                                   'GMT'
                                        ),
                                        tz = 'America/Chicago',
                                        '%Y-%m-%d'
                                      )
    )
  }
  
  ## Order the data frame by FIN, then assessment date
  cogDiag <- cogDiag[order(cogDiag$FIN, cogDiag$assessmentDate), ]
  ## Identifies patients with aphasia
  cg1 <- ifelse(cogDiag$langD %in%
                c('Anomic aphasia', 'Broca\'s aphasia',
                  'Broca\'s aphasia with reduced comprehension',
                  'Conduction aphasia', 'Global aphasia',
                  'Transcortical motor aphasia',
                  'Transcortical sensory aphasia',
                  'Undifferentiated aphasia fluent',
                  'Undifferentiated aphasia non-fluent', 'Wernicke\'s aphasia'
                ),
                1, 0
  )
  ## Identifies patients with right hemisphere dysfunction
  cg2 <- ifelse(cogDiag$cogComD ==
                'Cognitive - communication deficits associated with right hem',
                1, 0
  )
  ## Identifies patients with brain injury
  cg3 <- ifelse(cogDiag$cogComD ==
                'Cognitive - communication deficits associated with brain inj',
                1, 0
  )
  ## Identifies patients with undifferentiated cognitive communication deficits
  cg4 <- ifelse(cogDiag$cogComD == 'Cognitive - communication deficits', 1, 0)
  ## Identifies patients with reduced responsiveness/awaresness. Although
  ## future development is planned for and AQ-Cog form for these patients.
  ## That'll be a way down the road, however, as there aren't too many people
  ## with diagnoses like those.
  cg5 <- ifelse(cogDiag$cogComD ==
                'Reduced responsiveness and awareness',
                1, 0
  )
  ## Identifies patients with dysarthria
  vg1 <- ifelse(cogDiag$speD %in%
                c('Ataxic dysarthria', 'Flaccid dysarthria',
                  'Hyperkinetic dysarthria', 'Hypokinetic dysarthria',
                  'Mixed dysarthria', 'Spastic dysarthria',
                  'Undifferentiated dysarthria',
                  'Unilateral upper motor neuron dysarthria'
                ),
                1, 0
  )
  ## Identifies patients with aphonia/dysphonia
  vg2 <- ifelse(cogDiag$speD == 'Aphonia - dysphonia', 1, 0)
  ## Adds these to the cogDiag data.frame. I don't know why I did this in two
  ## steps, but oh well.
  cogDiag$cg1 <- cg1
  cogDiag$cg2 <- cg2
  cogDiag$cg3 <- cg3
  cogDiag$cg4 <- cg4
  cogDiag$cg5 <- cg5
  cogDiag$vg1 <- vg1
  cogDiag$vg2 <- vg2
  ## Changes any "Did not assess," "Could not assess," and "Impairment not
  ## identified" entries to missing values.
  if(any(cogDiag[, 3:6] == 'Did not assess', na.rm = T)){
    cogDiag[, 3:6][cogDiag[, 3:6] == 'Did not assess'] <- NA
  }
  if(any(cogDiag[, 3:6] == 'Could not assess', na.rm = T)){
    cogDiag[, 3:6][cogDiag[, 3:6] == 'Could not assess'] <- NA
  }
  if(any(cogDiag[, 3:6] == 'Impairment not identified', na.rm = T)){
    cogDiag[, 3:6][cogDiag[, 3:6] == 'Impairment not identified'] <- NA
  }
  ## This is a really compact but really confusing way to remove rows in which
  ## patients have no relevant diagnoses. I probably should have just written
  ## a function. Mea culpa.
  
  ##### LEAVE IN DEPENDING ON CLINICAL INPUT (OLD)
  # if(length(which(rownames(cogDiag) %in%
  #                 names(unlist(apply(cogDiag[, 3:6], 1,
  #                                    function(x) which(all(is.na(x)))
  #                              )
  #                 ))
  #    )) > 0
  # ){
  #   cogDiag <- cogDiag[-which(rownames(cogDiag) %in%
  #                             names(unlist(apply(
  #                                            cogDiag[, 3:6], 1,
  #                                            function(x) which(all(is.na(x)))
  #                                          )
  #                             ))
  #                       )
  #   , ]
  # }
  
  
  ## Assigns a numeric value to severity ratings
  cogDiag$cogComSrank <- ifelse(is.na(cogDiag$cogComS), -1,
                           ifelse(cogDiag$cogComS == 'Minimal', 0,
                           ifelse(cogDiag$cogComS == 'Mild', 1,
                           ifelse(cogDiag$cogComS == 'Mild - Moderate', 2,
                           ifelse(cogDiag$cogComS == 'Moderate', 3,
                           ifelse(cogDiag$cogComS == 'Moderately severe', 4,
                           ifelse(cogDiag$cogComS == 'Severe', 5, NA
  )))))))
  cogDiag$langSrank <- ifelse(is.na(cogDiag$langS), -1,
                         ifelse(cogDiag$langS == 'Minimal', 0,
                         ifelse(cogDiag$langS == 'Mild', 1,
                         ifelse(cogDiag$langS == 'Mild - Moderate', 2,
                         ifelse(cogDiag$langS == 'Moderate', 3,
                         ifelse(cogDiag$langS == 'Moderately severe', 4,
                         ifelse(cogDiag$langS == 'Severe', 5, NA
  )))))))
  cogDiag$speSrank <- ifelse(is.na(cogDiag$speS), -1,
                        ifelse(cogDiag$speS == 'Minimal', 0,
                        ifelse(cogDiag$speS == 'Mild', 1,
                        ifelse(cogDiag$speS == 'Mild - Moderate', 2,
                        ifelse(cogDiag$speS == 'Moderate', 3,
                        ifelse(cogDiag$speS == 'Moderately severe', 4,
                        ifelse(cogDiag$speS == 'Severe', 5, NA
  )))))))
  
  ## Forward impute diagnoses/ratings for each patient
  cgSplit <- split(cogDiag, paste(cogDiag$FIN))
  for(i in 1:length(cgSplit)){
    cgTemp <- cgSplit[i]
    cgTemp <- as.data.frame(cgTemp)
    colnames(cgTemp) <- colnames(cogDiag)
    cgTemp[, 4:19] <- apply(cgTemp[, 4:19], 2, repeat.before)
    cgTemp <- tail(cgTemp, 1)
    cgTemp <- split(cgTemp, paste(cgTemp$FIN))
    cgSplit <- replace(cgSplit, i, cgTemp)
  }
  cogDiag <- do.call('rbind', cgSplit)
  ## Assign severities of 0 when missing values are present.
  cogDiag[, 10:16] <- apply(cogDiag[, 10:16], c(1, 2),
                            function(x) ifelse(is.na(x), 0, x)
  )
  ## Convert to numeric values; again, splitting and recombining data.frames
  ## often results in R making bad decisions about data typing.
  cogDiag[, 10:16] <- apply(cogDiag[, 10:16], 2, as.numeric)
  ## Add primary and secondary diagnostic groups to the data.frame, which will
  ## be populated in the loop that follows.
  cogDiag$cogGroup <- NA
  cogDiag$cogGroup2 <- NA
  for(i in 1:nrow(cogDiag)){
    ## Creates indicator variables for each of the three types of diagnoses
    aphInd <- if(cogDiag$cg1[i] == 1) 'Aphasia' else NULL
    if(cogDiag$cg2[i] == 1){
      comInd <- 'RHD'
    }else if(cogDiag$cg3[i] == 1){
      comInd <- 'CCD-BI'
    }else if(cogDiag$cg4[i] == 1){
      comInd <- 'CCD'
    }else if(cogDiag$cg5[i] == 1){
      comInd <- 'RR'
    }else{
      comInd <- NULL
    }
    
    ##### LEAVE IN/DISCARD BASED ON CLINICAL INPUT (OLD)
    # if(cogDiag$vg1[i] == 1){
    #   speInd <- 'Dysarthria'
    # }else if(cogDiag$vg2[i] == 1){
    #   speInd <- 'Aphonia/Dysphonia'
    # }else{
    #   speInd <- NULL
    # }
    
    ## LEAVE IN/DISCARD BASED ON CLINICAL INPUT (NEW)
    if(cogDiag$vg1[i] == 1){
      speInd <- 'Dysarthria'
    }else if(cogDiag$vg2[i] == 1){
      speInd <- 'Aphonia/Dysphonia'
    }else if(cogDiag$vg1[i] == 0 && cogDiag$vg2[i] == 0 &&
             cogDiag$speSrank[i] > -1
    ){
      speInd <- 'Speech Disorder (Not Defined)'
    }else{
      speInd <- NULL
    }
    
    ## If all of those indicators are NULL, then simply assign a cognition
    ## group of "Other."
    if(all(is.null(c(aphInd, comInd, speInd)))){
      cogDiag$cogGroup[i] <- 'Other'
    ## Otherwise, if the patient is diagnosed with both aphasia and some flavor
    ## of CCD, put the patient in the group associated with the greater
    ## severity. If they're equal severities, note both.
    }else if(!is.null(aphInd) && !is.null(comInd)){
      if(cogDiag$langSrank[i] > cogDiag$cogComSrank[i]){
        cogDiag$cogGroup[i] <- aphInd
      }else if(cogDiag$langSrank[i] < cogDiag$cogComSrank[i]){
        cogDiag$cogGroup[i] <- comInd
      }else if(cogDiag$langSrank[i] == cogDiag$cogComSrank[i]){
        cogDiag$cogGroup[i] <- paste(c(trimws(paste(aphInd)),
                                       trimws(paste(comInd))
                                     ),
                                     collapse = ', '
        )
      }
    ## If the patient has both aphasia and speech disorder diagnoses, allow the
    ## aphiasia diagnosis to take priority
    }else if(!is.null(aphInd) && is.null(comInd) && !is.null(speInd)){
      cogDiag$cogGroup[i] <- aphInd
    ## If the patient has both a CCD and speech diagnosis, allow the CCD
    ## diagnosis to to take priority
    }else if(is.null(aphInd) && !is.null(comInd) && !is.null(speInd)){
      cogDiag$cogGroup[i] <- comInd
    ## If a patient only has a speech diagnosis, assign them to that group
    }else if(is.null(aphInd) && is.null(comInd) && !is.null(speInd)){
      cogDiag$cogGroup[i] <- speInd
    ## If a patient only has an aphasia diagnosis, assign them to that group
    }else if(!is.null(aphInd) && is.null(comInd) && is.null(speInd)){
      cogDiag$cogGroup[i] <- aphInd
    ## If a patient only has a CCD diagnosis, assign them to that group
    }else if(is.null(aphInd) && !is.null(comInd) && is.null(speInd)){
      cogDiag$cogGroup[i] <- comInd
    }
    ## If all the indicator values add to 0, put the patient in the "Other"
    ## group. If they add to more than that, paste all diagnoses separated
    ## by commas
    if(sum(cogDiag[i, 10:16]) < 1){
      cogDiag$cogGroup2[i] <- 'Other'
    }else{
      cogDiag$cogGroup2[i] <- paste(c(trimws(paste(aphInd)),
                                      trimws(paste(comInd)),
                                      trimws(paste(speInd))
                                    ),
                                    collapse = ', '
      )
    }
  }
  ## Pull out the needed columns for merging later.
  cogDiag <- cogDiag[, c(1:2, 20)]
  cogGroupMerge <- cogDiag[, c(1, 3)]

  ## With all of the querying done, close the connection to the EDW
  dbDisconnect(awsCon)
  
  ## Now we begin formatting data so that it's ready-made for the IRT
  ## scoring functions. There's a ton of it to be done, but it all runs pretty
  ## quickly. In fact, the bulk of start-up time for the dashboard rests within
  ## the queries above.
  
  ## A value of -1 is often used as a missing value in the EDW. Here, I convert
  ## those -1s to NAs. The conditionals prevent apply() from throwing errors
  ## when the data.frame is empty (0 rows).
  if(nrow(fist) > 0){
    fist[, 3:8] <- apply(fist[, 3:8], c(1, 2),
                         function(x) ifelse(x == -1, NA, x)
    )
  }
  if(nrow(bbs) > 0){
    bbs[, 3:8] <- apply(bbs[, 3:8], c(1, 2),
                        function(x) ifelse(x == -1, NA, x)
    )
  }
  if(nrow(fga) > 0){
    fga[, 3:7] <- apply(fga[, 3:7], c(1, 2),
                        function(x) ifelse(x == -1, NA, x)
    )
  }
  if(nrow(arat) > 0){
    arat[, 3:6] <- apply(arat[, 3:6], c(1, 2),
                         function(x) ifelse(x == -1, NA, x)
    )
  }
  ## The 999 here is for the special case where a patient is not able to
  ## complete the NHP. OTs, for whatever reason, will sometimes enter in a zero
  ## for the time. Because I want to assign those patients to the most severe
  ## category possible in these cases, I change the time to a high value.
  if(nrow(nhp) > 0){
    nhp[, 3:4] <- apply(nhp[, 3:4], c(1, 2),
                        function(x) ifelse(x == 0, 999, x)
    )
  }
  if(nrow(bft) > 0){
    bft[, 3:7] <- apply(bft[, 3:7], c(1, 2),
                        function(x) ifelse(x == -1, NA, x)
    )
  }
  if(nrow(masa) > 0){
    masa[, 3:12] <- apply(masa[, 3:12], c(1, 2),
                          function(x) ifelse(x == -1, NA, x)
    )
  }
  if(nrow(swl) > 0){
    swl[, 3:4] <- apply(swl[, 3:4], c(1, 2),
                        function(x) ifelse(x == -1, NA, x)
    )
  }
  
  ## Creates new objects that are ordered versions of their "raw" counterparts.
  ## I thought it important at the time of writing this to maintain the
  ## "un"edited data, but I've since decided against it. I could probably save
  ## a little memory overhead by simply overwriting throughout.
  fistO <- fist[order(fist$FIN, fist$assessmentDate), ]
  bbsO <- bbs[order(bbs$FIN, bbs$assessmentDate), ]
  fgaO <- fga[order(fga$FIN, fga$assessmentDate), ]
  aratO <- arat[order(arat$FIN, arat$assessmentDate), ]
  nhpO <- nhp[order(nhp$FIN, nhp$assessmentDate), ]
  bbO <- bb[order(bb$FIN, bb$assessmentDate), ]
  bftO <- bft[order(bft$FIN, bft$assessmentDate), ]
  pgO <- pg[order(pg$FIN, pg$assessmentDate), ]
  masaO <- masa[order(masa$FIN, masa$assessmentDate), ]
  swlO <- swl[order(swl$FIN, swl$assessmentDate), ]
  fimSCO <- fimSC[order(fimSC$FIN, fimSC$assessmentDate), ]
  
  ## This drops rows with all missing values. Reduce is a bit of a dinosaur
  ## dating back from the S+ days, so this bit requires a little explanation.
  ## Working from the innermost part of the function, the data itself is
  ## converted into a logical based on whether the entry in the data.frame is
  ## missing or not. The Reduce function with the ampersand operator performs
  ## an element by element check by row to determine if all values in that row
  ## are true. What we get, then, is a row index that indicates which rows
  ## have all missing values and should be dropped.
  fistCheck <- which(Reduce('&', as.data.frame(is.na(fistO[, 3:8]))))
  bbsCheck <- which(Reduce('&', as.data.frame(is.na(bbsO[, 3:8]))))
  fgaCheck <- which(Reduce('&', as.data.frame(is.na(fgaO[, 3:7]))))
  aratCheck <- which(Reduce('&', as.data.frame(is.na(aratO[, 3:6]))))
  nhpCheck <- which(Reduce('&', as.data.frame(is.na(nhpO[, 3:4]))))
  bbCheck <- which(Reduce('&', as.data.frame(is.na(bbO[, 3:4]))))
  bftCheck <- which(Reduce('&', as.data.frame(is.na(bftO[, 3:7]))))
  pgCheck <- which(Reduce('&', as.data.frame(is.na(pgO[, 3:6]))))
  masaCheck <- which(Reduce('&', as.data.frame(is.na(masaO[, 3:12]))))
  swlCheck <- which(Reduce('&', as.data.frame(is.na(swlO[, 3:4]))))
  fimSCCheck <- which(Reduce('&', as.data.frame(is.na(fimSCO[, 3:8]))))
  ## This bit drops the rows chosen above, if any
  if(length(fistCheck) > 0){
    fistO <- fistO[-fistCheck, ]
  }
  if(length(bbsCheck) > 0){
    bbsO <- bbsO[-bbsCheck, ]
  }
  if(length(fgaCheck) > 0){
    fgaO <- fgaO[-fgaCheck, ]
  }
  if(length(aratCheck) > 0){
    aratO <- aratO[-aratCheck, ]
  }
  if(length(nhpCheck) > 0){
    nhpO <- nhpO[-nhpCheck, ]
  }
  if(length(bbCheck) > 0){
    bbO <- bbO[-bbCheck, ]
  }
  if(length(bftCheck) > 0){
    bftO <- bftO[-bftCheck, ]
  }
  if(length(pgCheck) > 0){
    pgO <- pgO[-pgCheck, ]
  }
  if(length(masaCheck) > 0){
    masaO <- masaO[-masaCheck, ]
  }
  if(length(swlCheck) > 0){
    swlO <- swlO[-swlCheck, ]
  }
  if(length(fimSCCheck) > 0){
    fimSCO <- fimSCO[-fimSCCheck, ]
  }

  ## This creates a pasted together FIN and assessment date. It's a very useful
  ## value for merging data.frames.
  fistO$FINAD <- pasteFun(fistO$FIN, fistO$assessmentDate)
  bbsO$FINAD <- pasteFun(bbsO$FIN, bbsO$assessmentDate)
  fgaO$FINAD <- pasteFun(fgaO$FIN, fgaO$assessmentDate)
  aratO$FINAD <- pasteFun(aratO$FIN, aratO$assessmentDate)
  nhpO$FINAD <- pasteFun(nhpO$FIN, nhpO$assessmentDate)
  bbO$FINAD <- pasteFun(bbO$FIN, bbO$assessmentDate)
  bftO$FINAD <- pasteFun(bftO$FIN, bftO$assessmentDate)
  pgO$FINAD <- pasteFun(pgO$FIN, pgO$assessmentDate)
  masaO$FINAD <- pasteFun(masaO$FIN, masaO$assessmentDate)
  swlO$FINAD <- pasteFun(swlO$FIN, swlO$assessmentDate)
  fimSCO$FINAD <- pasteFun(fimSCO$FIN, fimSCO$assessmentDate)

  ## Recodes NHP data based on distributionally-derived cut-off values that I
  ## determined early on in AQ development. I take the natual logarithm due to
  ## the severe skew of the data. Recall the 999s assigned to 0 values earlier?
  ## That decision serves two purposes: 1) log_e(999) is roughly equal to 7,
  ## meaning that the patient will get scored a 0 on the ordinal scale set out
  ## below. Additionally, it avoids the issue with log(0) being undefined
  ## (though returning -Inf in R).
  if(nrow(nhpO) > 0){
    nhpO$nhpLpoly <- ifelse(log(nhpO$scoreLeft) < 3.296, 3,
                            ifelse(log(nhpO$scoreLeft) < 3.555, 2,
                            ifelse(log(nhpO$scoreLeft) < 3.912, 1, 0
    )))
    nhpO$nhpRpoly <- ifelse(log(nhpO$scoreRight) < 3.296, 3,
                            ifelse(log(nhpO$scoreRight) < 3.555, 2,
                            ifelse(log(nhpO$scoreRight) < 3.912, 1, 0
    )))
  }else{
    nhpO <- data.frame(MRN = NA, FIN = NA, scoreLeftNHP = NA,
                       scoreRightNHP = NA, assessmentDate = NA, FINAD = NA,
                       nhpLpoly = NA, nhpRpoly = NA
    )
    nhpO <- nhpO[-1, ]
  }
  ## Similar to the NHP, this converts the B&B to an ordinal scale based on
  ## splits in the distribution of performance.
  if(nrow(nhpO) > 0){
    bbO$bbLpoly <- ifelse(bbO$scoreLeft < 18, 0,
                          ifelse(bbO$scoreLeft < 33, 1,
                          ifelse(bbO$scoreLeft < 46, 2, 3
    )))
    bbO$bbRpoly <- ifelse(bbO$scoreRight < 18, 0,
                          ifelse(bbO$scoreRight < 33, 1,
                          ifelse(bbO$scoreRight < 46, 2, 3
    )))
  }else{
    bbO <- data.frame(MRN = NA, FIN = NA, scoreLeftBB = NA,
                      scoreRightBB = NA, assessmentDate = NA,
                      FINAD = NA, bbLpoly = NA, bbRpoly = NA
    )
    bbO <- bbO[-1, ]
  }
  ## Same as above, but for key grip and pinch strength
  if(nrow(pgO) > 0){
    pgO$keyPRpoly <- ifelse(pgO$keyPR < 6, 0,
                            ifelse(pgO$keyPR < 9, 1,
                            ifelse(pgO$keyPR < 13, 2, 3
    )))
    pgO$keyPLpoly <- ifelse(pgO$keyPL < 6, 0,
                            ifelse(pgO$keyPL < 9, 1,
                            ifelse(pgO$keyPL < 13, 2, 3
    )))
    pgO$gripRpoly <- ifelse(pgO$gripR < 17, 0,
                            ifelse(pgO$gripR < 32, 1,
                            ifelse(pgO$gripR < 50, 2, 3
    )))
    pgO$gripLpoly <- ifelse(pgO$gripL < 17, 0,
                            ifelse(pgO$gripL < 32, 1,
                            ifelse(pgO$gripL < 50, 2, 3
    )))
  }else{
    pgO <- data.frame(MRN = NA, FIN = NA, keyPR = NA, keyPL = NA, gripR = NA,
                      gripL = NA, assessmentDate = NA, FINAD = NA,
                      keyPRpoly = NA, keyPLpoly = NA, gripRpoly = NA,
                      gripLpoly = NA
    )
    pgO <- pgO[-1, ]
  }
  ## Recodes the MASA into a not stupid scoring format
  if(nrow(masaO) > 0){
    masaO$salivaC <- masaO$saliva - 1
    masaO$tongueMovementC <- car::recode(masaO$tongueMovement,
                                         "2=0;4=1;6=2;8=3;10=4"
    )
    masaO$tongueStrengthC <- car::recode(masaO$tongueStrength,
                                         "2=0;5=1;8=2;10=3"
    )
    masaO$tongueCoordinationC <- car::recode(masaO$tongueCoordination,
                                             "2=0;5=1;8=2;10=3"
    )
    masaO$oralPreparationC <- car::recode(masaO$oralPreparation,
                                          "2=0;4=1;6=2;8=3;10=4"
    )
    masaO$bolusClearanceC <- car::recode(masaO$bolusClearance,
                                         "2=0;5=1;8=2;10=3"
    )
    masaO$oralTransitC <- car::recode(masaO$oralTransit,
                                      "2=0;4=1;6=2;8=3;10=4"
    )
    masaO$voluntaryCoughC <- car::recode(masaO$voluntaryCough,
                                         "2=0;5=1;8=2;10=3"
    )
    masaO$pharyngealPhaseC <- car::recode(masaO$pharyngealPhase,
                                          "2=0;5=1;8=2;10=3"
    )
    masaO$pharyngealResponseC <- car::recode(masaO$pharyngealResponse,
                                             "1=0;5=1;10=2"
    )
  }else{
    masaO <- data.frame(MRN = NA, FIN = NA, saliva = NA, tongueMovement = NA,
                        tongueStrength = NA, tongueCoordination = NA,
                        oralPreparation = NA, bolusClearance = NA,
                        oralTransit = NA, voluntaryCough = NA,
                        pharyngealPhase = NA, pharyngealResponse = NA,
                        assessmentDate = NA, FINAD = NA, salivaC = NA,
                        tongueMovementC = NA, tongueStrengthC = NA,
                        tongueCoordinationC = NA, oralPreparationC = NA,
                        bolusClearanceC = NA, oralTransitC = NA,
                        voluntaryCoughC = NA, pharyngealPhaseC = NA,
                        pharyngealResponseC = NA
    )
    masaO <- masaO[-1, ]
  }
  ## Converts the FOIS and RIC-DSS into 0-n scales
  if(nrow(swlO) > 0){
    swlO$foisC <- swlO$fois - 1
    swlO$ricdssC <- swlO$dysphagiaSupervisionLevel - 1
  }else{
    swlO <- data.frame(MRN = NA, FIN = NA, fois = NA,
                       dysphagiaSuversionLevel = NA, assessmentDate = NA,
                       FINAD = NA, foisC = NA, ricdssC = NA
    )
    swlO <- swlO[-1, ]
  }
  ## Converts the FIM-SC into 0-6 instead of 1-7.
  if(nrow(fimSCO) > 0){
    fimSCO[, 3:8] <- apply(fimSCO[, 3:8], 2, as.numeric)
    fimSCO[, 3:8] <- fimSCO[, 3:8] - 1
  }else{
    fimSCO <- data.frame(MRN = NA, FIN = NA, eating = NA, grooming = NA,
                         bathing = NA, dressingUpper = NA, dressingLower = NA,
                         toileting = NA, assessmentDate = NA, FINAD = NA
    )
    fimSCO <- fimSCO[-1, ]
  }

  ## Applies the minByDay() function to each column of the dataset.
  if(nrow(fistO) > 0){
    fistMin <- minByDay(fistO, 10, 3:8, qi = F)
  }else{
    fistMin <- fistO
  }
  if(nrow(bbsO) > 0){
    bbsMin <- minByDay(bbsO, 10, 3:8, qi = F)
  }else{
    bbsMin <- bbsO
  }
  if(nrow(fgaO) > 0){
    fgaMin <- minByDay(fgaO, 9, 3:7, qi = F)
  }else{
    fgaMin <- fgaO
  }
  if(nrow(aratO) > 0){
    aratMin <- minByDay(aratO, 8, 3:6, qi = F)
  }else{
    aratMin <- aratO
  }
  if(nrow(nhpO) > 0){
    nhpMin <- minByDay(nhpO, 6, 7:8, qi = F)
  }else{
    nhpMin <- nhpO
  }
  if(nrow(bbO) > 0){
    bbMin <- minByDay(bbO, 6, 7:8, qi = F)
  }else{
    bbMin <- bbO
  }
  if(nrow(bftO) > 0){
    bftMin <- minByDay(bftO, 9, 3:7, qi = F)
  }else{
    bftMin <- bftO
  }
  if(nrow(pgO) > 0){
    pgMin <- minByDay(pgO, 8, 9:12, qi = F)
  }else{
    pgMin <- pgO
  }
  if(nrow(masaO) > 0){
    masaMin <- minByDay(masaO, 14, 15:24, qi = F)
  }else{
    masaMin <- masaO
  }
  if(nrow(swlO) > 0){
    swlMin <- minByDay(swlO, 6, 7:8, qi = F)
  }else{
    swlMin <- swlO
  }
  if(nrow(fimSCO) > 0){
    fimSCMin <- minByDay(fimSCO, 10, 3:8, qi = F)
  }else{
    fimSCMin <- fimSCO
  }

  ## Removes columns we don't need from our data.frames
  nhpMin2 <- nhpMin[, -(3:4)]
  bbMin2 <- bbMin[, -(3:4)]
  pgMin2 <- pgMin[, -(3:6)]
  masaMin2 <- masaMin[, -(3:12)]
  swlMin2 <- swlMin[, -(3:4)]
  
  ## Finally, we can merge all of the self-care domain AQ data into one big
  ## data.frame.
  bal1 <- merge(fistMin, bbsMin,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  bal <- merge(bal1, fgaMin,
               by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  uef1 <- merge(aratMin, nhpMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  uef2 <- merge(uef1, bbMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  uef3 <- merge(uef2, bftMin,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  uef <- merge(uef3, pgMin2,
               by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  swl <- merge(masaMin2, swlMin2,
               by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  sc1 <- merge(bal, uef,
               by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  sc2 <- merge(sc1, swl,
               by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  sc <- merge(sc2, fimSCMin,
              by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  
  ## Final "just in case" conversion of the ordinally scored AQ data into
  ## numeric type
  sc[, 5:56] <- apply(sc[, 5:56], 2, as.numeric)
  
  ## And some last-second recoding that I probably should have done above.
  sc$standingUnsupported <- car::recode(sc$standingUnsupported,
                                        "0=0;1=0;2=0;3=1;4=2;"
  )
  sc$standingToSitting <- car::recode(sc$standingToSitting,
                                      "0=0;1=0;2=1;3=2;4=3;"
  )
  sc$graspWood10 <- car::recode(sc$graspWood10,
                                "0=0;1=0;2=1;3=2;"
  )
  sc$gripTube2p25 <- car::recode(sc$gripTube2p25,
                                 "0=0;1=0;2=1;3=2;"
  )
  sc$grossHandToMouth <- car::recode(sc$grossHandToMouth,
                                     "0=0;1=0;2=1;3=2;"
  )
  sc$salivaC <- car::recode(sc$salivaC,
                            "0=0;1=0;2=0;3=1;4=2;"
  )
  sc$tongueMovementC <- car::recode(sc$tongueMovementC,
                                    "0=0;1=0;2=1;3=2;4=3;"
  )
  sc$tongueCoordinationC <- car::recode(sc$tongueCoordinationC,
                                        "0=0;1=0;2=1;3=2;"
  )
  sc$pharyngealPhaseC <- car::recode(sc$pharyngealPhaseC,
                                     "0=0;1=0;2=1;3=2;"
  )
  sc$grooming <- car::recode(sc$grooming,
                             "0=0;1=0;2=0;3=1;4=2;5=3;6=4;"
  )
  sc$bathing <- car::recode(sc$bathing,
                            "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
  )
  sc$dressingLower <- car::recode(sc$dressingLower,
                                  "0=0;1=0;2=1;3=2;4=3;5=4;6=5;"
  )
  sc$toileting <- car::recode(sc$toileting,
                              "0=0;1=1;2=2;3=3;4=4;5=5;6=5;"
  )

  ## With the Mobility and Cognition groups already determined up with the
  ## SQL queries, this is where we get our balance-determined Self-Care groups.
  scGroupInd <- data.frame(FIN = unique(hp$FIN),
                           fistInd = rep(NA, length(unique(hp$FIN))),
                           bbsInd = rep(NA, length(unique(hp$FIN))),
                           fgaInd = rep(NA, length(unique(hp$FIN)))
  )
  scGroupInd$siBal <- sapply(scGroupInd$FIN,
                             function(x) ifelse(x %in% fistMin$FIN, 1, 0)
  )
  scGroupInd$stBal <- sapply(scGroupInd$FIN,
                             function(x) ifelse(x %in% bbsMin$FIN, 1, 0)
  )
  scGroupInd$waBal <- sapply(scGroupInd$FIN,
                             function(x) ifelse(x %in% fgaMin$FIN, 1, 0)
  )
  scGroupInd$scGroup <- apply(scGroupInd[, 5:7], 1,
                              function(x) ifelse(x[1] == 0 &&
                                                 x[2] == 0 &&
                                                 x[3] == 0, 1,
                                            ifelse(x[1] == 1 &&
                                                   x[2] == 0 &&
                                                   x[3] == 0, 1,
                                            ifelse(x[2] == 1 &&
                                                   x[3] == 0, 2, 3
  ))))
  scGroupMerge <- scGroupInd[, c(1, 8)]

  ## Now we start modifying the Mobility data to prepare it for IRT scoring.
  
  ## Recode Pressure Relief into the proper format
  if(nrow(pRel) > 0){
    pRel$score <- as.numeric(pRel$score)
    pRel$score <- pRel$score - 1
  }else{
    pRel <- data.frame(MRN = NA, FIN = NA, score = NA, assessmentDate = NA)
    pRel <- pRel[-1, ]
  }
  ## Recode FMS data (not that there's ever any FMS data...)
  if(nrow(fms) > 0){
    fms[, 3:5] <- apply(fms[, 3:5], 2, as.numeric)
    fms[, 3:5] <- fms[, 3:5] - 1
  }else{
    fms <- data.frame(MRN = NA, FIN = NA, supine2LongSit = NA,
                      shortSit2Mat = NA, selfROM = NA, assessmentDate = NA
    )
    fms <- fms[-1, ]
  }
  ## Convert Ten Meter Walk to numeric type, then take the mean of the trials
  if(nrow(tenMeter) > 0){
    tenMeter[, 3:4] <- apply(tenMeter[, 3:4], 2, as.numeric)
    tenMeter$tmMean <- rowMeans(tenMeter[, 3:4], na.rm = T)
  }else{
    tenMeter <- data.frame(MRN = NA, FIN = NA, tenMeter1 = NA, tenMeter2 = NA,
                           assessmentDate = NA, tmMean = NA
    )
    tenMeter <- tenMeter[-1, ]
  }
  ## Convert the Six Minute Walk to numeric
  if(nrow(sixMinW) > 0){
    sixMinW$sixMinW <- as.numeric(sixMinW$sixMinW)
  }else{
    sixMinW <- data.frame(MRN = NA, FIN = NA, sixMinW = NA,
                          assessmentDate = NA
    )
    sixMinW <- sixMinW[-1, ]
  }
  ## Convert the Six Minute Push to numeric
  if(nrow(sixMinP) > 0){
    sixMinP$sixMinP <- as.numeric(sixMinP$sixMinP)
  }else{
    sixMinP <- data.frame(MRN = NA, FIN = NA, sixMinP = NA,
                          assessmentDate = NA
    )
    sixMinP <- sixMinP[-1, ]
  }
  ## Recode the FIM to 0-6 scoring
  if(nrow(fimMob) > 0){
    fimMob[, 3:8] <- apply(fimMob[, 3:8], 2, as.numeric)
    fimMob[, 3:8] <- fimMob[, 3:8] - 1
  }

  ## The rest of this is kinda the same as the Self Care bit
  pRelO <- pRel[order(pRel$FIN, pRel$assessmentDate), ]
  fmsO <- fms[order(fms$FIN, fms$assessmentDate), ]
  fiveTimesO <- fiveTimes[order(fiveTimes$FIN, fiveTimes$assessmentDate), ]
  tenMeterO <- tenMeter[order(tenMeter$FIN, tenMeter$assessmentDate), ]
  sixMinWO <- sixMinW[order(sixMinW$FIN, sixMinW$assessmentDate), ]
  sixMinPO <- sixMinP[order(sixMinP$FIN, sixMinP$assessmentDate), ]
  fimMobO <- fimMob[order(fimMob$FIN, fimMob$assessmentDate), ]
  fimMOLO <- fimMOL[order(fimMOL$FIN, fimMOL$assessmentDate), ]
    
  pRelCheck <- which(Reduce('&', as.data.frame(is.na(pRelO[, 3]))))
  fmsCheck <- which(Reduce('&', as.data.frame(is.na(fmsO[, 3:6]))))
  fiveTimesCheck <- which(Reduce('&', as.data.frame(is.na(fiveTimesO[, 3]))))
  tenMeterCheck <- which(Reduce('&', as.data.frame(is.na(tenMeterO[, 6]))))
  sixMinWCheck <- which(Reduce('&', as.data.frame(is.na(sixMinWO[, 3]))))
  sixMinPCheck <- which(Reduce('&', as.data.frame(is.na(sixMinPO[, 3]))))
  fimMobCheck <- which(Reduce('&', as.data.frame(is.na(fimMobO[, 3:8]))))
  fimMOLCheck <- which(Reduce('&', as.data.frame(is.na(fimMOL[, 3]))))
  
  if(length(pRelCheck) > 0){
    pRelO <- pRelO[-pRelCheck, ]
  }
  if(length(fmsCheck) > 0){
    fmsO <- fmsO[-fmsCheck, ]
  }
  if(length(fiveTimesCheck) > 0){
    fiveTimesO <- fiveTimesO[-fiveTimesCheck, ]
  }
  if(length(tenMeterCheck) > 0){
    tenMeterO <- tenMeterO[-tenMeterCheck, ]
  }
  if(length(sixMinWCheck) > 0){
    sixMinWO <- sixMinWO[-sixMinWCheck, ]
  }
  if(length(sixMinPCheck) > 0){
    sixMinPO <- sixMinPO[-sixMinPCheck, ]
  }
  if(length(fimMobCheck) > 0){
    fimMobO <- fimMobO[-fimMobCheck, ]
  }
  ## If the MoL goal hasn't been entered for a patient, this just assumes that
  ## they're in the wheelchair group. This can, of course, be edited on the
  ## dashboard.
  if(length(fimMOLCheck) > 0){
    fimMOLO$molGoal[fimMOLCheck] <- 'Wheelchair'
  }
  
  pRelO$FINAD <- mapply(pasteFun, pRelO$FIN, pRelO$assessmentDate)
  fmsO$FINAD <- mapply(pasteFun, fmsO$FIN, fmsO$assessmentDate)
  fiveTimesO$FINAD <- mapply(pasteFun, fiveTimesO$FIN,
                             fiveTimesO$assessmentDate
  )
  tenMeterO$FINAD <- mapply(pasteFun, tenMeterO$FIN, tenMeterO$assessmentDate)
  sixMinWO$FINAD <- mapply(pasteFun, sixMinWO$FIN, sixMinWO$assessmentDate)
  sixMinPO$FINAD <- mapply(pasteFun, sixMinPO$FIN, sixMinPO$assessmentDate)
  fimMobO$FINAD <- mapply(pasteFun, fimMobO$FIN, fimMobO$assessmentDate)
  fimMOLO$FINAD <- mapply(pasteFun, fimMOLO$FIN, fimMOLO$assessmentDate)
  
  ## Does the requisite recoding for Pressure Relief.
  if(nrow(pRelO) > 0){
    pRelO$score <- car::recode(pRelO$score, "0=0;1=1;2=1;3=1;4=2;5=2")
  }
  ## Recodes the 5x StS into ordinal categories, much like the NHP in the
  ## self-care bit.
  if(nrow(fiveTimesO) > 0){
    fiveTimesO$ftCat <- ifelse(fiveTimesO$fiveTimes == 0, 0,
                        ifelse(log(fiveTimesO$fiveTimes) < 2.25, 5,
                        ifelse(log(fiveTimesO$fiveTimes) < 2.7, 4,
                        ifelse(log(fiveTimesO$fiveTimes) < 3.5, 3,
                        ifelse(log(fiveTimesO$fiveTimes) < 4.1, 2, 1
    )))))
  }
  ## Same for the Ten Meter Walk
  if(nrow(tenMeterO) > 0){
    tenMeterO$tmCat <- ifelse(log(tenMeterO$tmMean) < -3, 0,
                       ifelse(log(tenMeterO$tmMean) < -1.7, 1,
                       ifelse(log(tenMeterO$tmMean) < -1, 2,
                       ifelse(log(tenMeterO$tmMean) < 0, 3, 4
    ))))
  }
  ## And the Six Minute Walk
  if(nrow(sixMinWO) > 0){
    sixMinWO$smwCat <- ifelse(sixMinWO$sixMinW == 0, 0,
                       ifelse(log(sixMinWO$sixMinW) < 3.4, 1,
                       ifelse(log(sixMinWO$sixMinW) < 4.6, 2,
                       ifelse(log(sixMinWO$sixMinW) < 5.7, 3,
                       ifelse(log(sixMinWO$sixMinW) < 6.9, 4, 5
    )))))
  }
  ## And the Six Minute Push
  if(nrow(sixMinPO) > 0){
    sixMinPO$smpCat <- ifelse(sixMinPO$sixMinP == 0, 0,
                       ifelse(log(sixMinPO$sixMinP) < 4.2, 0,
                       ifelse(log(sixMinPO$sixMinP) < 4.9, 1,
                       ifelse(log(sixMinPO$sixMinP) < 6.3, 2,
                       ifelse(log(sixMinPO$sixMinP) < 7, 3,
                       ifelse(log(sixMinPO$sixMinP) < 7.4, 4, 5
    ))))))
  }
  ## Recodes the Tub/Shower Transfer item as the last two categories are
  ## collapsed
  if(nrow(fimMobO) > 0){
    fimMobO$tubShowerTransfer <- car::recode(fimMobO$tubShowerTransfer,
                                             "0=0;1=1;2=2;3=3;4=4;5=5;6=5"
    )
  }
  
  if(nrow(pRelO) > 0){
    pRelMin <- minByDay(pRelO, 5, 3, qi = F)
  }else{
    pRelMin <- pRelO
  }
  if(nrow(fmsO) > 0){
    fmsMin <- minByDay(fmsO, 7, 3:5, qi = F)
  }else{
    fmsMin <- fmsO
  }
  if(nrow(fiveTimesO) > 0){
    fiveTimesMin <- minByDay(fiveTimesO, 5, 6, qi = F)
  }else{
    fiveTimesMin <- fiveTimesO
  }
  if(nrow(tenMeterO) > 0){
    tenMeterMin <- minByDay(tenMeterO, 7, 8, qi = F)
  }else{
    tenMeterMin <- tenMeterO
  }
  if(nrow(sixMinWO) > 0){
    sixMinWMin <- minByDay(sixMinWO, 5, 6, qi = F)
  }else{
    sixMinWMin <- sixMinWO
  }
  if(nrow(sixMinPO) > 0){
    sixMinPMin <- minByDay(sixMinPO, 5, 6, qi = F)
  }else{
    sixMinPMin <- sixMinPO
  }
  if(nrow(fimMobO) > 0){
    fimMobMin <- minByDay(fimMobO, 10, 3:8, qi = F)
  }else{
    fimMobMin <- fimMobO
  }
  
  fiveTimesMin2 <- fiveTimesMin[, -3]
  sixMinWMin2 <- sixMinWMin[, -3]
  sixMinPMin2 <- sixMinPMin[, -3]
  tenMeterMin2 <- tenMeterMin[, -c(3:4, 6)]
  
  if(nrow(fiveTimesMin2) < 1){
    fiveTimesMin2 <- data.frame(MRN = NA, FIN = NA, assessmentDate = NA,
                                FINAD = NA, ftCat = NA
    )
  }
  if(nrow(sixMinWMin2) < 1){
    sixMinWMin2 <- data.frame(MRN = NA, FIN = NA, assessmentDate = NA,
                              FINAD = NA, smwCat = NA
    )
  }
  if(nrow(sixMinPMin2) < 1){
    sixMinPMin2 <- data.frame(MRN = NA, FIN = NA, assessmentDate = NA,
                              FINAD = NA, smpCat = NA
    )
  }
  if(nrow(tenMeterMin2) < 1){
    tenMeterMin2 <- data.frame(MRN = NA, FIN = NA, assessmentDate = NA,
                               FINAD = NA, tmCat = NA
    )
  }

  ## And now we have our AQ-Mob data frame.
  mob1 <- merge(bal, pRelMin,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  mob2 <- merge(mob1, fmsMin,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  mob3 <- merge(mob2, fiveTimesMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  mob4 <- merge(mob3, sixMinWMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  mob5 <- merge(mob4, sixMinPMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  mob6 <- merge(mob5, tenMeterMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  mob <- merge(mob6, fimMobMin,
               by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  
  mob[, 5:35] <- apply(mob[, 5:35], 2, as.numeric)
  if(any(is.na(mob$FIN))){
    mob <- mob[!is.na(mob$FIN), ]
  }
  
  ## Prepares the mobGroupMerge data.frame for merging later.
  mobGroupInd <- data.frame(FIN = unique(hp$FIN))
  mobGroupInd <- merge(mobGroupInd, fimMOLO[, c(1, 3)], by = 'FIN', all.x = T)
  mobGroupMerge <- mobGroupInd
  if(length(is.na(mobGroupMerge$molGoal)) > 0){
    mobGroupMerge$molGoal[is.na(mobGroupMerge$molGoal)] <- 'Wheelchair'
  }
  
  ## Finally, we can edit the Cognition data for IRT scoring.
  
  ## Convert the O-Log to numeric
  if(nrow(olog) > 0){
    olog[, 3:8] <- apply(olog[, 3:8], 2, as.numeric)
  }
  ## Convert the ABS to numeric
  if(nrow(abs) > 0){
    abs[, 3:6] <- apply(abs[, 3:6], 2, as.numeric)
    abs[, 3:6] <- 4 - abs[, 3:6]
  }
  ## Convert the RICE3 to numeric and rescale so the lowest scoring category is
  ## zero.
  if(nrow(ric3) > 0){
    ric3[, 3:4] <- apply(ric3[, 3:4], 2, as.numeric) - 1
  }
  ## Recode the TWR to numeric
  colnames(twr)[3] <- 'twr'
  if(nrow(twr) > 0){
    twr$twr <- as.numeric(twr$twr)
  }
  ## Recode the Rivermead immediate and delayed story recall items into
  ## ordinal scales. Interestingly, the delayed data are skewed, but the
  ## immediate data are not.
  if(nrow(rvmd) > 0){
    rvmd[, 3:4] <- apply(rvmd[, 3:4], 2, as.numeric)
    rvmd$rvmdImm <- ifelse(rvmd$storyImmediateRaw <= 4, 0,
                           ifelse(rvmd$storyImmediateRaw <= 7, 1,
                           ifelse(rvmd$storyImmediateRaw <= 10, 2, 3
    )))
    rvmd$rvmdDel <- ifelse(rvmd$storyDelayedRaw == 0, 0,
                           ifelse(log(rvmd$storyDelayedRaw) <= .6931, 0,
                           ifelse(log(rvmd$storyDelayedRaw) <= 1.609, 1,
                           ifelse(log(rvmd$storyDelayedRaw) <= 2.14, 2, 3
    ))))
  }else{
    rvmd$rvmdImm <- numeric(0)
    rvmd$rvmdDel <- numeric(0)
  }
  ## Convert the AIDS to ordinal
  if(nrow(aids) > 0){
    aids[, 3:4] <- apply(aids[, 3:4], 2, as.numeric)
    aids$sniw <- ifelse(aids$shortNumberOfIntelligibleWords <= 12, 0,
                        ifelse(aids$shortNumberOfIntelligibleWords <= 18, 1,
                        ifelse(aids$shortNumberOfIntelligibleWords <= 22, 2, 3
    )))
    aids$siws <- ifelse(aids$shortIntelligibleWordsInSentences <= 95.5, 0,
                        ifelse(aids$shortIntelligibleWordsInSentences <= 106.2,
                               1, 2
    ))
  }else{
    aids$sniw <- numeric(0)
    aids$siws <- numeric(0)
  }
  ## Recode the VMs to ordinal
  if(nrow(vm) > 0){
    vm[, 3:8] <- apply(vm[, 3:8], 2, as.numeric)
    vm$spMean <- apply(vm[, 3:5], 1, function(x) mean(x, na.rm = T))
    vm$viMean <- apply(vm[, 6:8], 1, function(x) mean(x, na.rm = T))
    vm$spC <- ifelse(vm$spMean <= 4.333, 0,
                     ifelse(vm$spMean <= 7.333, 1,
                     ifelse(vm$spMean <= 11.33, 2, 3
    )))
    vm$viC <- ifelse(vm$viMean <= 69.33, 0,
                     ifelse(vm$viMean <= 74, 1,
                     ifelse(vm$viMean <= 79.67, 2, 3
    )))
  }else{
    vm$spMean <- numeric(0)
    vm$viMean <- numeric(0)
    vm$spC <- numeric(0)
    vm$viC <- numeric(0)
  }
  ## Recode the BDAE subtests
  if(nrow(bdae) > 0){
    bdae$basicworddiscshortC <- ifelse(bdae$basicWordDiscShort <= 4, 0,
                                  ifelse(bdae$basicWordDiscShort <= 8, 1,
                                  ifelse(bdae$basicWordDiscShort <= 12, 2, 3
    )))
    bdae$commandsshortC <- ifelse(bdae$commandsShort <= 2, 0,
                                  ifelse(bdae$commandsShort <= 7, 1, 2
    ))
    bdae$complexideationalshortC <- ifelse(bdae$complexIdeationalShort == 0, 0,
                                      ifelse(bdae$complexIdeationalShort <= 2,
                                             1,
                                      ifelse(bdae$complexIdeationalShort <= 4,
                                             2, 3
    )))
    bdae$wordrepetitionshortC <- ifelse(bdae$wordRepetitionShort <= 1, 0,
                                   ifelse(bdae$wordRepetitionShort <= 3, 1,
                                   ifelse(bdae$wordRepetitionShort == 4, 2, 3
    )))
    bdae$sentencerepetitionshortC <- ifelse(bdae$sentenceRepetitionShort == 0,
                                            0,
                                       ifelse(
                                         bdae$sentenceRepetitionShort == 1,
                                         1, 2
    ))
    bdae$specialcategoriesshortC <- ifelse(bdae$specialCategoriesShort <= 5, 0,
                                      ifelse(bdae$specialCategoriesShort <= 11,
                                             1, 2
    ))
    bdae$formshortC <- ifelse(bdae$formShort <= 6, 0,
                              ifelse(bdae$formShort <= 10, 1, 2
    ))
    bdae$letterchoiceshortC <- ifelse(bdae$letterChoiceShort <= 6, 0,
                                 ifelse(bdae$letterChoiceShort <= 15, 1, 2
    ))
    bdae$motorfacilityshortC <- ifelse(bdae$motorFacilityShort <= 6, 0,
                                  ifelse(bdae$motorFacilityShort == 7, 1, 2
    ))
    bdae$picturewordmatchingshortC <- bdae$pictureWordMatchingShort
    bdae$oralwordreadingshortC <- ifelse(bdae$oralWordReadingShort <= 3, 0,
                                    ifelse(bdae$oralWordReadingShort <= 14,
                                           1, 2
    ))
    bdae$oralsentencereadingshortC <- ifelse(
                                        bdae$oralSentenceReadingShort <= 1, 0,
                                        ifelse(
                                          bdae$oralSentenceReadingShort <= 3,
                                          1, 2
    ))
    bdae$oralsentencecomprehensionshortC <- ifelse(
      bdae$oralSentenceComprehensionShort == 0, 0,
      ifelse(bdae$oralSentenceComprehensionShort <= 2, 1, 2
    ))
    bdae$sentenceparagraphcomprehensionshortC <- ifelse(
      bdae$sentenceParagraphComprehensionShort <= 1, 0,
      ifelse(bdae$sentenceParagraphComprehensionShort <= 3, 1, 2
    ))
  }else{
    bdae$basicworddiscshortC <- numeric(0)
    bdae$commandsshortC <- numeric(0)
    bdae$complexideationalshortC <- numeric(0)
    bdae$wordrepetitionshortC <- numeric(0)
    bdae$sentencerepetitionshortC <- numeric(0)
    bdae$specialcategoriesshortC <- numeric(0)
    bdae$formshortC <- numeric(0)
    bdae$letterchoiseshortC <- numeric(0)
    bdae$motorfacilityshortC <- numeric(0)
    bdae$picturewordmatchingshortC <- numeric(0)
    bdae$oralwordreadingshortC <- numeric(0)
    bdae$oralsentencereadingshortC <- numeric(0)
    bdae$oralsentencecomprehensionshortC <- numeric(0)
    bdae$sentenceparagraphcomprehensionshortC <- numeric(0)
  }
  ## Rather than using the BNTs scoring scale which only counts spontaneous
  ## recall and certain types of cues, I use weighted scoring for each type
  ## of correct response, then convert those scores into an ordinal scale.
  if(nrow(bnt) > 0){
    bnt[, 3:6] <- apply(bnt[, 3:6], 2, as.numeric)
    if(length(which(matrix(apply(bnt[, 3:6], 1,
                                 function(x) all(is.na(x)))) == T
       )) > 0
    ){
      bnt <- bnt[-which(matrix(apply(bnt[, 3:6], 1,
                                     function(x) all(is.na(x))
                               )
                        ) == T)
      , ]
    }
    bntMat <- as.matrix(bnt[, 3:6], ncol = 4, byrow = T)
    bntMat[is.na(bntMat)] <- 0
    bntWt <- matrix(c(.4, .3, .2, .1), ncol = 1)
    bnt$bntWtScore <- bntMat %*% bntWt
    bnt$bntC <- ifelse(bnt$bntWtScore <= .9, 0,
                       ifelse(bnt$bntWtScore <= 3.75, 1,
                       ifelse(bnt$bntWtScore <= 5.4, 2, 3
    )))
  }else{
    bnt$bntWtScore <- numeric(0)
    bnt$bntC <- numeric(0)
  }
  ## Convert FIM-Cog to numeric and recode to 0-6
  if(nrow(fimCog) > 0){
    fimCog[, 3:7] <- apply(fimCog[, 3:7], 2, as.numeric)
    fimCog[, 3:7] <- fimCog[, 3:7] - 1
  }
  
  ## This probably looks pretty familiar by now...
  ologO <- olog[order(olog$FIN, olog$assessmentDate), ]
  absO <- abs[order(abs$FIN, abs$assessmentDate), ]
  ric3O <- ric3[order(ric3$FIN, ric3$assessmentDate), ]
  twrO <- twr[order(twr$FIN, twr$assessmentDate), ]
  rvmdO <- rvmd[order(rvmd$FIN, rvmd$assessmentDate), ]
  aidsO <- aids[order(aids$FIN, aids$assessmentDate), ]
  vmO <- vm[order(vm$FIN, vm$assessmentDate), ]
  bdaeO <- bdae[order(bdae$FIN, bdae$assessmentDate), ]
  bntO <- bnt[order(bnt$FIN, bnt$assessmentDate), ]
  fimCogO <- fimCog[order(fimCog$FIN, fimCog$assessmentDate), ]
  
  ologCheck <- which(Reduce(`&`,as.data.frame(is.na(ologO[, 3:8]))))
  absCheck <- which(Reduce(`&`,as.data.frame(is.na(absO[, 3:6]))))
  ric3Check <- which(Reduce(`&`,as.data.frame(is.na(ric3O[, 3:4]))))
  twrCheck <- which(Reduce(`&`,as.data.frame(is.na(twrO[, 3]))))
  rvmdCheck <- which(Reduce(`&`,as.data.frame(is.na(rvmdO[, 6:7]))))
  aidsCheck <- which(Reduce(`&`,as.data.frame(is.na(aidsO[, 6:7]))))
  vmCheck <- which(Reduce(`&`,as.data.frame(is.na(vmO[, 12:13]))))
  bdaeCheck <- which(Reduce(`&`,as.data.frame(is.na(bdaeO[, 18:31]))))
  bntCheck <- which(Reduce(`&`,as.data.frame(is.na(bntO[, 9]))))
  fimCogCheck <- which(Reduce(`&`,as.data.frame(is.na(fimCogO[, 3:7]))))
  
  if(length(ologCheck) > 0){
    ologO <- ologO[-ologCheck, ]
  }
  if(length(absCheck) > 0){
    absO <- absO[-absCheck, ]
  }
  if(length(ric3Check) > 0){
    ric3O <- ric3O[-ric3Check, ]
  }
  if(length(twrCheck) > 0){
    twrO <- twrO[-twrCheck, ]
  }
  if(length(rvmdCheck) > 0){
    rvmdO <- rvmdO[-rvmdCheck, ]
  }
  if(length(aidsCheck) > 0){
    aidsO <- aidsO[-aidsCheck, ]
  }
  if(length(vmCheck) > 0){
    vmO <- vmO[-vmCheck, ]
  }
  if(length(bdaeCheck) > 0){
    bdaeO <- bdaeO[-bdaeCheck, ]
  }
  if(length(bntCheck) > 0){
    bntO <- bntO[-bntCheck, ]
  }
  if(length(fimCogCheck) > 0){
    fimCogO <- fimCogO[-fimCogCheck, ]
  }
  
  ologO$FINAD <- mapply(pasteFun, ologO$FIN, ologO$assessmentDate)
  absO$FINAD <- mapply(pasteFun, absO$FIN, absO$assessmentDate)
  ric3O$FINAD <- mapply(pasteFun, ric3O$FIN, ric3O$assessmentDate)
  twrO$FINAD <- mapply(pasteFun, twrO$FIN, twrO$assessmentDate)
  rvmdO$FINAD <- mapply(pasteFun, rvmdO$FIN, rvmdO$assessmentDate)
  aidsO$FINAD <- mapply(pasteFun, aidsO$FIN, aidsO$assessmentDate)
  vmO$FINAD <- mapply(pasteFun, vmO$FIN, vmO$assessmentDate)
  bdaeO$FINAD <- mapply(pasteFun, bdaeO$FIN, bdaeO$assessmentDate)
  bntO$FINAD <- mapply(pasteFun, bntO$FIN, bntO$assessmentDate)
  fimCogO$FINAD <- mapply(pasteFun, fimCogO$FIN, fimCogO$assessmentDate)
  
  if(nrow(ologO) > 0){
    ologMin <- minByDay(ologO, 10, 3:8, qi = F)
  }else{
    ologMin <- ologO
  }
  if(nrow(absO) > 0){
    absMin <- minByDay(absO, 8, 3:6, qi = F)
  }else{
    absMin <- absO
  }
  if(nrow(ric3O) > 0){
    ric3Min <- minByDay(ric3O, 6, 3:4, qi = F)
  }else{
    ric3Min <- ric3O
  }
  if(nrow(twrO) > 0){
    twrMin <- minByDay(twrO, 5, 3, qi = F)
  }else{
    twrMin <- twrO
  }
  if(nrow(rvmdO) > 0){
    rvmdMin <- minByDay(rvmdO, 8, 6:7, qi = F)
  }else{
    rvmdMin <- rvmdO
  }
  if(nrow(aidsO) > 0){
    aidsMin <- minByDay(aidsO, 8, 6:7, qi = F)
  }else{
    aidsMin <- aidsO
  }
  if(nrow(vmO) > 0){
    vmMin <- minByDay(vmO, 14, 12:13, qi = F)
  }else{
    vmMin <- vmO
  }
  if(nrow(bdaeO) > 0){
    bdaeMin <- minByDay(bdaeO, 32, 18:31, qi = F)
  }else{
    bdaeMin <- bdaeO
  }
  if(nrow(bntO) > 0){
    bntMin <- minByDay(bntO, 10, 9, qi = F)
  }else{
    bntMin <- bntO
  }
  if(nrow(fimCogO) > 0){
    fimCogMin <- minByDay(fimCogO, 9, 3:7, qi = F)
  }else{
    fimCogMin <- fimCogO
  }
  
  rvmdMin2 <- rvmdMin[, -c(3:4)]
  aidsMin2 <- aidsMin[, -c(3:4)]
  vmMin2 <- vmMin[, -c(3:8, 10:11)]
  bdaeMin2 <- bdaeMin[, -c(3:16)]
  bntMin2 <- bntMin[, -c(3:6, 8)]
  
  ## New merge into our AQ-Cog data.frame
  cog1 <- merge(ologMin, absMin,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog2 <- merge(cog1, ric3Min,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog3 <- merge(cog2, twrMin,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog4 <- merge(cog3, rvmdMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog5 <- merge(cog4, aidsMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog6 <- merge(cog5, vmMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog7 <- merge(cog6, bdaeMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog8 <- merge(cog7, bntMin2,
                by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  cog <- merge(cog8, fimCogMin,
               by = c('MRN', 'FIN', 'assessmentDate', 'FINAD'), all = T
  )
  
  if(nrow(cog > 0)){
    cog[, 5:43] <- apply(cog[, 5:43], 2, as.numeric)
  }
  
  ## At this point, we now have all of the AQ data in exactly the format we
  ## need it. All that's left is to sew up the patient table to be ready for
  ## display on the dashboard.
  
  ## Merge the patient data.frame with the assessment groups
  hp <- merge(hp, scGroupMerge, by = 'FIN', all.x = T)
  hp <- merge(hp, mobGroupMerge, by = 'FIN', all.x = T)
  hp <- merge(hp, cogGroupMerge, by = 'FIN', all.x = T)
  hp <- hp[order(hp$Admit), ]
  ## Though redundant at this point, check once again for any duplicated
  ## patients.
  if(any(duplicated(hp))){
    hp <- hp[-which(duplicated(hp)), ]
  }
  if(any(is.na(hp$FIN))){
    hp <- hp[!is.na(hp$FIN), ]
  }
  ## I'm only doing this not to mess with previously written reactiveValue
  ## assignments later.
  hp <- hp[, c(1:8, 10:13, 9)]
  
  ## Unfortunately, due to the intricacies of assessment procedure, we don't
  ## always have the CMG by a patient's first team conference. That's because
  ## "Does not occur" is often used during a patient's initial evaluation.
  ## This bit of code does its best to estimate a patient's CMG with what
  ## information is provided.
  hp$imputedCMG <- NA
  if(any(is.na(hp$CMG))){
    fimCMG <- fim
    fimCMG[, 3:19] <- apply(fim[, 3:19], 2, as.numeric)
    ## Drop all missing values
    fimCMG[, 3:19] <- apply(fim[, 3:19], c(1, 2),
                            function(x) ifelse(x %in% c(9, 44, 88), NA, x)
    )
    ## Impute backward. That's right, I didn't have to write my own function.
    ## I didn't know about zoo::na.locf() until I wrote this part of the code.
    fimCMGSplit <- split(fimCMG, paste(fimCMG$FIN))
    for(i in 1:length(fimCMGSplit)){
      cmgPat <- as.data.frame(fimCMGSplit[i])
      colnames(cmgPat) <- colnames(fimCMG)
      cmgPat[, 3:19] <- as.data.frame(
                          apply(cmgPat[, 3:19], 2,
                                function(x) as.numeric(na.locf(x,
                                                               na.rm = F,
                                                               rev = T
                                                       ))
                          )
      )
      cmgPat <- split(head(cmgPat, 1), paste(cmgPat$FIN))
      fimCMGSplit <- replace(fimCMGSplit, i, cmgPat)
    }
    ## Takes the first row of each of the 
    fimCMG <- do.call('rbind', fimCMGSplit)
    ## Now we start getting into estimating the CMG
    if(any(is.na(fimCMG))){
      ## Compute the mean of each of the areas within the FIM
      scCMG_mu <- apply(fimCMG[, 3:8], 1, function(x) mean(x, na.rm = T))
      mobCMG_mu <- apply(fimCMG[, 9:14], 1, function(x) mean(x, na.rm = T))
      cogCMG_mu <- apply(fimCMG[, 15:19], 1, function(x) mean(x, na.rm = T))
      for(i in 1:nrow(fimCMG)){
        ## Impute those means for missing values within each FIM area
        if(any(is.na(fimCMG[i, 3:8]))){
          for(j in 3:8){
            fimCMG[i, j] <- ifelse(is.na(fimCMG[i, j]),
                                   scCMG_mu[i], fimCMG[i, j]
            )
          }
        }
        if(any(is.na(fimCMG[i, 9:14]))){
          for(j in 9:14){
            fimCMG[i, j] <- ifelse(is.na(fimCMG[i, j]),
                                   mobCMG_mu[i], fimCMG[i, j]
            )
          }
        }
        if(any(is.na(fimCMG[i, 15:19]))){
          for(j in 15:19){
            fimCMG[i, j] <- ifelse(is.na(fimCMG[i, j]),
                                   cogCMG_mu[i], fimCMG[i, j]
            )
          }
        }
      }
    }
    for(i in 1:nrow(hp)){
      ## If the patient has a stroke diagnosis and had their CMG imputed
      ## above...
      if(is.na(hp$CMG[i]) &&
         hp$FIN[i] %in% fimCMG$FIN &&
         hp$MedicalService[i] %in%
           c('Stroke', 'Stroke Prime of Life',
             'Stroke Locked-In Syndrome'
           )
      ){
        ## Make a note that the CMG was imputed
        hp$imputedCMG[i] <- 1
        ## Pull out the Motor and Cog subscores
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        cmgAge <- hp$Age[i]
        ## Assign a CMG
        hp$CMG[i] <- ifelse(cmgMot >= 51.05, '0101',
                            ifelse(cmgMot >= 44.45 && cmgCog >= 18.5, '0102',
                            ifelse(cmgMot >= 44.45 && cmgCog < 18.5, '0103',
                            ifelse(cmgMot >= 38.85 && cmgMot < 44.45, '0104',
                            ifelse(cmgMot >= 34.25 && cmgMot < 38.85, '0105',
                            ifelse(cmgMot >= 30.05 && cmgMot < 34.25, '0106',
                            ifelse(cmgMot >= 26.15 && cmgMot < 30.05, '0107',
                            ifelse(cmgMot < 26.15 && cmgAge > 84.5, '0108',
                            ifelse(cmgMot >= 22.35 && cmgMot < 26.15 &&
                                   cmgAge < 84.5, '0109', '0110'
        )))))))))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('Brain Injury Traumatic', 'Brain Injury Traumatic AMiCouS',
                   'Brain injury Traumatic Post AMiCouS'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 53.35 && cmgCog >= 23.5, '0201',
                            ifelse(cmgMot >= 44.25 && cmgCog >= 23.5, '0202',
                            ifelse(cmgMot >= 44.25 && cmgCog < 23.5, '0203',
                            ifelse(cmgMot >= 40.65 && cmgMot < 44.25, '0204',
                            ifelse(cmgMot >= 28.75 && cmgMot < 40.65, '0205',
                            ifelse(cmgMot >= 22.05 && cmgMot < 28.75, '0206',
                                   '0207'
        ))))))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('BI Non Traumatic - Onc',
                   'Brain Injury Non Traumatic Post AMiCouS',
                   'Brain Injury Nontraumatic',
                   'Brain Injury Nontraumatic AMiCouS'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 41.05, '0301',
                            ifelse(cmgMot >= 35.05 && cmgMot < 41.05, '0302',
                            ifelse(cmgMot >= 26.15 && cmgMot < 35.05, '0303',
                                   '0304'
        )))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('SCI Traumatic - Other', 'SCI Traumatic - Para',
                   'SCI Traumatic - Quad',
                   'SCI Traumatic Late Effects - Para',
                   'SCI Traumatic Late Effects - Quad',
                   'Sci Traumatic Vent'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        cmgAge <- hp$Age[i]
        hp$CMG[i] <- ifelse(cmgMot >= 48.45, '0401',
                            ifelse(cmgMot >= 30.35 && cmgMot < 48.45, '0402',
                            ifelse(cmgMot >= 16.05 && cmgMot < 30.35, '0403',
                            ifelse(cmgMot < 16.05 && cmgAge > 63.5, '0404',
                            '0405'
        ))))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('SCI Non Traumatic - Onc', 'Sci Nontraumatic',
                   'Sci Nontraumatic Vent'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 51.35, '0501',
                            ifelse(cmgMot >= 40.15 && cmgMot < 51.35, '0502',
                            ifelse(cmgMot >= 31.25 && cmgMot < 40.15, '0503',
                            ifelse(cmgMot >= 29.25 && cmgMot < 31.25, '0504',
                            ifelse(cmgMot >= 23.75 && cmgMot < 29.25, '0505',
                                   '0506'
        )))))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('Neuro  Multiple Sclerosis', 'Neuro  Parkinsons',
                   'Neuro Parkinsons DBS', 'Neurological',
                   'Neurological Vent'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 47.75, '0601',
                            ifelse(cmgMot >= 37.35 && cmgMot < 47.74, '0602',
                            ifelse(cmgMot >= 25.85 && cmgMot < 37.35, '0603',
                                   '0604'
        )))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('Fracture LE - Onc',
                   'Fracture Lower Extremity'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 42.15, '0701',
                            ifelse(cmgMot >= 34.15 && cmgMot < 42.15, '0702',
                            ifelse(cmgMot >= 28.15 && cmgMot < 34.15, '0703',
                                   '0704'
        )))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('LE joint Replacement - Bilateral',
                   'LE Joint Replacement - Unilateral'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        cmgAge <- hp$Age[i]
        hp$CMG[i] <- ifelse(cmgMot >= 49.55, '0801',
                            ifelse(cmgMot >= 37.05 && cmgMot < 49.55, '0802',
                            ifelse(cmgMot >= 28.65 && cmgMot < 37.05 &&
                                   cmgAge > 83.5, '0803',
                            ifelse(cmgMot >= 28.65 && cmgMot < 37.05 &&
                                   cmgAge < 83.5, '0804',
                            ifelse(cmgMot >= 22.05 && cmgMot < 28.65, '0805',
                                   '0806'
        )))))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Other Orthopedic'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 44.75, '0901',
                            ifelse(cmgMot >= 34.35 && cmgMot < 44.75, '0902',
                            ifelse(cmgMot >= 24.15 && cmgMot < 34.35, '0903',
                                   '0904'
        )))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Amp Lower Extremity'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 47.65, '1001',
                            ifelse(cmgMot >= 36.25 && cmgMot < 47.65, '1002',
                                   '1003'
        ))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Amp Other'
      ){
        hp$imputedCMG[i] <- 1
        hp$CMG[i] <- ifelse(cmgMot >= 36.35, '1101', '1102')
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Osteo and other Arthritis'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 37.65, '1201',
                            ifelse(cmgMot >= 30.75 && cmgMot < 37.65, '1202',
                                   '1203'
        ))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Rheumatoid Arthritis'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 36.35, '1301',
                            ifelse(cmgMot >= 26.15 && cmgMot < 36.35, '1302',
                                   '1303'
        ))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Cardiac'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 48.85, '1401',
                            ifelse(cmgMot >= 38.55 && cmgMot < 48.85, '1402',
                            ifelse(cmgMot >= 31.15 && cmgMot < 38.55, '1403',
                                   '1404'
        )))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Pulmonary'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 49.15, '1501',
                            ifelse(cmgMot >= 39.05 && cmgMot < 49.15, '1502',
                            ifelse(cmgMot >= 29.15 && cmgMot < 39.05, '1503',
                                   '1504'
        )))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Pain'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 37.15, '1601',
                            ifelse(cmgMot >= 26.75 && cmgMot < 37.15, '1602',
                                   '1603'
        ))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Maj Mlt Trma W/O Bi Or Sci'
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 39.25, '1701',
                            ifelse(cmgMot >= 31.05 && cmgMot < 39.25, '1702',
                            ifelse(cmgMot >= 25.55 && cmgMot < 31.05, '1703',
                                   '1704'
        )))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('Maj Mlt Trma W/Bi Or Sci - B',
                   'Maj Mlt Trma W/Bi Or Sci - S',
                   'Maj Mlt Trma W/Bi Or Sci Vent'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 40.85, '1801',
                            ifelse(cmgMot >= 23.05 && cmgMot < 40.85, '1802',
                                   '1803'
        ))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('Guillian Barre', 'Guillian Barre Vent')
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 35.95, '1901',
                            ifelse(cmgMot >= 18.05 && cmgMot < 35.95, '1902',
                                   '1903'
        ))
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] == 'Burn'
      ){
        hp$CMG[i] <- '2101'
      }else if(is.na(hp$CMG[i]) &&
               hp$FIN[i] %in% fimCMG$FIN &&
               hp$MedicalService[i] %in%
                 c('General Debility', 'Med Complex - Other',
                   'Med Complex - Stem Cell Transplant',
                   'Med Complex - Transplant Heart/Lun',
                   'Med Complex - Transplant Liver/Kid',
                   'Med Complex  - Onc'
                 )
      ){
        hp$imputedCMG[i] <- 1
        cmgMot <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 3:14])
        cmgCog <- sum(fimCMG[which(fimCMG$FIN == hp$FIN[i]), 15:19])
        hp$CMG[i] <- ifelse(cmgMot >= 49.15, '2001',
                            ifelse(cmgMot >= 38.75 && cmgMot < 49.15, '2002',
                            ifelse(cmgMot >= 27.85 && cmgMot < 38.75, '2003',
                                   '2004'
        )))
      }
    }
  }

  ## Set aside the rows that we'd actually like to show users on the dashboard
  hpDisplay <- hp[, c(1, 3:7, 9)]
  hpDisplay$Floor <- gsub('Floor ', '', hpDisplay$Floor)
  ## Indicate with an asterisk which CMGs were imputed so users are aware
  for(i in 1:nrow(hpDisplay)){
    hpDisplay$CMG[i] <- ifelse(!is.na(hp$imputedCMG[i]),
                               paste(hp$CMG[i], '*', sep = ''), hp$CMG[i]
    )
  }
  
  ## Wrap up the patient table in a fancy datatable
  patientDT <- DT::datatable(hpDisplay,
                             rownames = F,
                             selection = 'single',
                             options = list(autowidth = T,
                                            pageLength = 5,
                                            dom = 'ftp',
                                            searching = F
                             )
  )
  ## This bit adds the shadow class to the #dtWrapper div once the table has
  ## loaded. That's why it's not run until here; we don't want the shadow
  ## around the div to appear while the loading animation is running.
  runjs(showShadow)
  
  ## And, finally, render that datatable at the top of the dashboard
  output$patientDT <- DT::renderDataTable(patientDT, style = "font-size: 150%;")
  }   # Data operations
  
  {
  ## "Universal" reactive values. uv$prog and uv$goal are now deprecated; they
  ## controlled some display options that are no longer present.
  uv <- reactiveValues()
  uv$dom <- 'sc'
  uv$prog <- 1
  uv$goal <- 'bar'
  
  ## Containers for other various reactive values that will be created when
  ## the dashboard is running.
  rv <- reactiveValues()
  gv <- reactiveValues()
  sv <- reactiveValues()
  tv <- reactiveValues()
  pv <- reactiveValues()
  
  ## These RVs are used for the FIM Update part of the dashboard
  rv$fimSCO <- fimSCO
  rv$fimMobO <- fimMob
  rv$fimCogO <- fimCogMin
  }   # Reactive value setup

  print(proc.time() - ptm) # Timer finish
  
  ## This event observer is triggered when a patient is selected at the top of
  ## the dashboard. Everything above this runs before the user does anything.
  observeEvent(input$patientDT_rows_selected, {
    {
    ## These are all values that we don't want to "leak" between patients.
    ## to err on the side of caution, they're invalidated between patients and
    ## then progressively overwritten.
    uv$update <- NULL
    rv$scSco <- NULL
    rv$mobSco <- NULL
    rv$cogSco <- NULL
    predDates <- NULL
    rv$predPlot <- NULL
    rv$fimPlot <- NULL
    rv$pal <- NULL
    rv$xAx <- NULL
    rv$yAx <- NULL
    fimScores <- NULL
    fimActual <- NULL
    fimGoals <- NULL
    fimPred <- NULL
    rv$fimPlot <- NULL
    rv$newGoals <- NULL
    rv$newGoalsSC <- NULL
    rv$newGoalsMob <- NULL
    rv$newGoalsCog <- NULL
    gv$scgroup <- NULL
    gv$mobgroup <- NULL
    gv$coggroup <- NULL
    gv$losgroup <- NULL
    gv$eat <- NA
    gv$groom <- NA
    gv$bath <- NA
    gv$ubDress <- NA
    gv$lbDress <- NA
    gv$toilet <- NA
    gv$bcTrans <- NA
    gv$tsTrans <- NA
    gv$tTrans <- NA
    gv$locWalk <- NA
    gv$locWheel <- NA
    gv$locStairs <- NA
    gv$comp <- NA
    gv$exp <- NA
    gv$si <- NA
    gv$ps <- NA
    gv$mem <- NA
    gv$mobSco <- NULL
    gv$toPlot <- NULL
    gv$mobPred <- NULL
    gv$predPlot <- NULL
    gv$fgLineDat <- NULL
    gv$fgLine <- NULL
    gv$predPlotFull <- NULL
    tv$fimPar <- NULL
    tv$tlPreds <- NULL
    tv$fimItems <- NULL
    tv$funLevels <- NULL
    tv$funLevelsR <- NULL
    tv$tlData <- NULL
    tv$losgroup <- NULL
    tv$nullCogTL <- 0
    tv$scgroup <- NULL
    tv$mobgroup <- NULL
    tv$coggroup <- NULL
    pv$mobgroup <- NULL
    pv$toPlot_goals <- NULL
    pv$fimPlot <- NULL
    uv$balsc_switch <- 1
    uv$uef_switch <- 1
    uv$swl_switch <- 1
    uv$balmob_switch <- 1
    uv$wc_switch <- 1
    uv$xfer_switch <- 1
    uv$cbp_switch <- 1
    uv$com_switch <- 1
    uv$wcom_switch <- 1
    uv$comp_switch <- 1
    uv$spe_switch <- 1
    uv$mem_switch <- 1
    uv$agi_switch <- 1
    rv$datSC <- NULL
    rv$datMob <- NULL
    rv$datCog <- NULL
    } # reactive value invalidation
    
    ## Records the patient information in the selected row.
    rv$row <- hp[as.numeric(input$patientDT_rows_selected), ]
    {
    ## Record the patient's FIN
    rv$fin <- isolate(as.character(rv$row[1]))
    ## Record the medical service/diagnosis
    rv$ms <- isolate(as.character(rv$row[4]))
    ## Code the patient's medical service into a group for the predictive model
    rv$msg <- ifelse(as.character(rv$row[4]) %in%
                     c('Sci Nontraumatic Vent', 'SCI Traumatic - Quad',
                       'SCI Traumatic Late Effects - Quad',
                       'Sci Traumatic Vent', 'Maj Mlt Trma W/Bi Or Sci - S'
                     ),'A',
                ifelse(as.character(rv$row[4]) %in%
                       c('SCI Non Traumatic - Onc', 'Sci Nontraumatic',
                         'SCI Traumatic - Other', 'SCI Traumatic - Para',
                         'SCI Traumatic Late Effects - Para'
                       ), 'B',
                ifelse(as.character(rv$row[4]) %in%
                       c('Stroke', 'Stroke Prime of Life'), 'C',
                ifelse(as.character(rv$row[4]) %in%
                       c('Stroke Locked-In Syndrome', 'Stroke Vent'), 'D',
                ifelse(as.character(rv$row[4]) %in%
                       c('Brain Injury Nontraumatic', 'Brain Injury Traumatic',
                         'Maj Mlt Trma W/Bi Or Sci - B',
                         'BI Non Traumatic - Onc',
                         'Brain Injury Non Traumatic Post AMiCouS',
                         'Brain Injury Nontraumatic AMiCouS',
                         'Brain injury Traumatic Post AMiCouS'
                       ), 'E',
                ifelse(as.character(rv$row[4]) %in%
                       c('Neuro  Multiple Sclerosis', 'Neuro  Parkinsons',
                         'Neuro  Parkinsons DBS'
                       ), 'F',
                ifelse(as.character(rv$row[4]) %in%
                       c('Amp Lower Extremity', 'Amp Other', 'Cardiac',
                         'Fracture LE - Onc', 'Fracture Lower Extremity',
                         'General Debility', 'Maj Mlt Trma W/O Bi Or Sci',
                         'Med Complex  - Onc', 'Med Complex - Other',
                         'Med Complex - Stem Cell Transplant',
                         'Med Complex - Transplant Heart/Lun',
                         'Med Complex - Transplant Liver/Kid',
                         'Other Orthopedic', 'Pulmonary',
                         'Rheumatoid Arthritis', 'Osteo and other Arthritis'
                       ), 'G',
                ifelse(as.character(rv$row[4]) %in%
                       'Brain Injury Traumatic AMiCouS', 'H',
                ifelse(as.character(rv$row[4]) %in%
                       c('Guillian Barre', 'Neurological'), 'I',
                ifelse(as.character(rv$row[4]) %in%
                       'Neurological Vent', 'J',
                ifelse(as.character(rv$row[4]) %in% 'Burn', 'K', 'L'
    )))))))))))
    ## Record the patient's CMG
    rv$cmg <- isolate(as.character(rv$row[5]))
    rv$cmg <- ifelse(isolate(rv$cmg) == '0203', '0204', isolate(rv$cmg))
    ## Record the floor of the hospital the patient is staying on
    rv$floor <- isolate(as.character(rv$row[6]))
    ## Record the patient's current LoS
    rv$los <- isolate(as.numeric(Sys.Date() - as.Date(unlist(rv$row[7]),
                                                      origin = '1970-01-01'
                                              )
    ))
    ## Get the patient's approximate LoS group (can be changed by user)
    if(!is.na(isolate(rv$cmg))){
      if(!is.na(isolate(rv$row$ExpDepart))){
        rv$explos <- as.numeric(isolate(rv$row$ExpDepart - rv$row$Admit))
      }else{
        rv$explos <- cmglos$los[intersect(which(cmglos$msg == isolate(rv$msg)),
                                          which(cmglos$cmg == isolate(rv$cmg)
                                ))
        ]
      }
    }else{
      rv$explos <- NA
    }
    if(length(isolate(rv$explos)) < 1){
      rv$explos <- NA
    }
    ## Record the patient's admission date
    rv$admit <- isolate(rv$row[7]$Admit)
    ## And their expected departure
    rv$depart <- isolate(rv$row[8]$ExpDepart)
    ## Assign the LoS group
    if(!is.na(isolate(rv$explos))){
      rv$losgroup <- ifelse(isolate(rv$explos) < 3, 1,
                     ifelse(isolate(rv$explos) <= 18, 2,
                     ifelse(isolate(rv$explos) <= 23, 3,
                     ifelse(isolate(rv$explos) <= 30, 4,
                     ifelse(isolate(rv$explos) <= 36, 5, 6
      )))))
    }else{
      rv$losgroup <- ifelse(isolate(rv$los) < 3, 1,
                     ifelse(isolate(rv$los) <= 18, 2,
                     ifelse(isolate(rv$los) <= 23, 3,
                     ifelse(isolate(rv$los) <= 30, 4,
                     ifelse(isolate(rv$los) <= 36, 5, 6
      )))))
    }
    rv$losgroup <- isolate(max(c(rv$losgroup, 2)))
    ## Record the patient's AQ-SC group
    rv$scgroup <- isolate(as.numeric(rv$row[10]))
    ## Record the patient's AQ-Mob group
    rv$mobgroup <- as.numeric(ifelse(isolate(rv$row[11]) == 'Wheelchair', 1,
                              ifelse(isolate(rv$row[11]) == 'Both', 2,
                              ifelse(isolate(rv$row[11]) == 'Walk', 3, NA
    ))))
    ## Record the patient's AQ-Cog group
    
    ##### REMOVE "SPEECH DISORDER (NOT DEFINED) DEPENDING ON CLINICAL FEEDBACK
    rv$coggroup <- as.numeric(ifelse(isolate(rv$row[12]) %in% c('Aphasia', 'Aphasia, CCD'), 1,
                              ifelse(isolate(rv$row[12]) == 'CCD', 2,
                              ifelse(isolate(rv$row[12]) == 'CCD-BI', 3,
                              ifelse(isolate(rv$row[12]) == 'RHD', 4,
                              ifelse(isolate(rv$row[12]) %in%
                                     c('Aphonia/Dysphonia', 'Dysarthria',
                                       'Speech Disorder (Not Defined)'
                                     ),
                                     5, NA
    ))))))
    ## Pull the patient's self-care predictive model
    rv$scPred <- scPreds$yhat6[intersect(
                                 intersect(
                                   which(scPreds$scgroup == rv$scgroup),
                                   which(scPreds$msg == rv$msg)
                                 ),
                                 intersect(
                                   which(scPreds$cmg == rv$cmg),
                                   which(scPreds$longstay == rv$losgroup)
                                 )
                               )
    ]
    rv$scPred51 <- isolate(rv$scPred)
    ## As well as the mobility predictive model
    rv$mobPred <- mobPreds$yhat6[intersect(
                                   intersect(
                                     which(mobPreds$mobgroup == rv$mobgroup),
                                     which(mobPreds$msg == rv$msg)
                                   ),
                                   intersect(
                                     which(mobPreds$cmg == rv$cmg),
                                     which(mobPreds$longstay == rv$losgroup)
                                   )
                                 )
    ]
    rv$mobPred51 <- isolate(rv$mobPred)
    ## And also the cognition predictive model
    rv$cogPred <- cogPreds$yhat6[intersect(
                                   intersect(
                                     which(cogPreds$coggroup == rv$coggroup),
                                     which(cogPreds$msg == rv$msg)
                                   ),
                                   intersect(
                                     which(cogPreds$cmg == rv$cmg),
                                     which(cogPreds$longstay == rv$losgroup)
                                   )
                                 )
    ]
    rv$cogPred51 <- isolate(rv$cogPred)
    ## Save predictive model info more generically; this is helpful in some of
    ## the functions at the top of the page (use CTRL+F to find out where).
    rv$scPredAllG <- isolate(scPreds[intersect(which(scPreds$cmg == rv$cmg),
                                               which(scPreds$msg == rv$msg)
                                     )
    , ])
    rv$mobPredAllG <- isolate(mobPreds[intersect(which(mobPreds$cmg == rv$cmg),
                                                 which(mobPreds$msg == rv$msg)
                                       )
    , ])
    rv$cogPredAllG <- isolate(cogPreds[intersect(which(cogPreds$cmg == rv$cmg),
                                                 which(cogPreds$msg == rv$msg)
                                       )
    , ])
    ## Pull out the data for the selected patient
    rv$scData <- isolate(sc[sc$FIN == rv$fin, ])
    rv$mobData <- isolate(mob[mob$FIN == rv$fin, ])
    rv$cogData <- isolate(cog[cog$FIN == rv$fin, ])
    ## Compute AQ-SC scores
    isolate(
      if(dim(rv$scData)[1] > 0){
        rv$scSco <- scoFunSCFIM(data = rv$scData, group = rv$scgroup)
      }else{
        rv$scSco <- NULL
      }
    )
    ## Check to see if there's any AQ-Mob data
    if(dim(isolate(rv$mobData))[1] < 1){
      nacheck <- 1
    }else{
      nacheckData <- isolate(rv$mobData)
      ## Recheck for "Does not occur" data.
      if(any(nacheckData[, 5:35] > 10, na.rm = T)){
        nacheckData[, 5:35] <- apply(nacheckData[, 5:35], c(1, 2),
                                     function(x) ifelse(x > 10 && !is.na(x),
                                                        NA, x
                                                 )
        )
      }
      if(isolate(rv$mobgroup) == 1){
        nacheck <- ifelse(all(
                            is.na(
                              nacheckData[, c(5:10, 22:25, 28, 30:32, 34)]
                            )
                          ),
                          1, 0
        )
      }else if(isolate(rv$mobgroup) == 2){
        nacheck <- ifelse(all(is.na(nacheckData[, c(5:16, 22, 26:35)])), 1, 0)
      }else if(isolate(rv$mobgroup) == 3){
        nacheck <- ifelse(all(is.na(nacheckData[, c(11:21, 26:35)])), 1, 0)
      }
    }
    ## Compute AQ-Mob scores
    isolate(
      if(dim(rv$mobData)[1] > 0 && nacheck == 0){
        rv$mobSco <- scoFunMobFIM(data = rv$mobData, group = rv$mobgroup)
      }else{
        rv$mobSco <- NULL
      }
    )
    ## Compute AQ-Cog scores
    isolate(
      if(dim(rv$cogData)[1] > 0){
        if(!is.na(isolate(rv$coggroup))){
          rv$cogSco <- scoFunCogFIM(data = rv$cogData, group = rv$coggroup)
        }else{
          rv$cogSco <- NULL
        }
      }else{
        rv$cogSco <- NULL
      }
    )
    ## Set aside FIM ratings for the Update FIM functionality
    if(isolate(rv$fin) %in% fim$FIN){
      if(any(!is.na(fim[fim$FIN == isolate(rv$fin), 3:8]))){
        tempFIM <- fim[fim$FIN == isolate(rv$fin), 3:8]
        if(nrow(tempFIM) > 1){
          rv$datSC <- tail(apply(tempFIM, 2, repeat.before), 1)
        }else{
          rv$datSC <- tempFIM
        }
        isolate(
          rv$datSC <- data.frame(eating = rv$datSC[1], grooming = rv$datSC[2],
                                 bathing = rv$datSC[3],
                                 dressingUpper = rv$datSC[4],
                                 dressingLower = rv$datSC[5],
                                 toileting = rv$datSC[6]
          )
        )
      }else{
        rv$datSC <- data.frame(eating = NA, grooming = NA, bathing = NA,
                               dressingUpper = NA, dressingLower = NA,
                               toileting = NA
        )
      }
    }else{
      rv$datSC <- data.frame(eating = NA, grooming = NA, bathing = NA,
                             dressingUpper = NA, dressingLower = NA,
                             toileting = NA
      )
    }
    if(isolate(rv$fin) %in% fim$FIN){
      if(any(!is.na(fim[fim$FIN == isolate(rv$fin), 9:14]))){
        tempFIM <- fim[fim$FIN == isolate(rv$fin), 9:14]
        if(nrow(tempFIM) > 1){
          rv$datMob <- tail(apply(tempFIM, 2, repeat.before), 1)
        }else{
          rv$datMob <- tempFIM
        }
        isolate(
          rv$datMob <- data.frame(bedChairTransfer = rv$datMob[1],
                                  tubShowerTransfer = rv$datMob[2],
                                  toiletTransfer = rv$datMob[3],
                                  locomotionWalk = rv$datMob[4],
                                  locomotionWheelchair = rv$datMob[5],
                                  locomotionStairs = rv$datMob[6]
          )
        )
      }else{
        rv$datMob <- data.frame(bedChairTransfer = NA, tubShowerTransfer = NA,
                                toiletTransfer = NA, locomotionWalk = NA,
                                locomotionWheelchair = NA,
                                locomotionStairs = NA
        )
      }
    }else{
      rv$datMob <- data.frame(bedChairTransfer = NA, tubShowerTransfer = NA,
                              toiletTransfer = NA, locomotionWalk = NA,
                              locomotionWheelchair = NA, locomotionStairs = NA
      )
    }
    if(isolate(rv$fin) %in% fim$FIN){
      if(any(!is.na(fim[fim$FIN == isolate(rv$fin), 15:19]))){
        tempFIM <- fim[fim$FIN == isolate(rv$fin), 15:19]
        if(nrow(tempFIM) > 1){
          rv$datCog <- tail(apply(tempFIM, 2, repeat.before), 1)
        }else{
          rv$datCog <- tempFIM
        }
        isolate(
          rv$datCog <- data.frame(comprehension = rv$datCog[1],
                                  expression = rv$datCog[2],
                                  socialInteraction = rv$datCog[3],
                                  problemSolving = rv$datCog[4],
                                  memory = rv$datCog[5]
          )
        )
      }else{
        rv$datCog <- data.frame(comprehension = NA, expression = NA,
                                socialInteraction = NA, problemSolving = NA,
                                memory = NA
        )
      }
    }else{
      rv$datCog <- data.frame(comprehension = NA, expression = NA,
                              socialInteraction = NA, problemSolving = NA,
                              memory = NA
      )
    }
    } # reactive value population
    
    ## Based off the RVs computed above, this will render the desired view of
    ## the dashboard
    renderDisplay()
    
    ## Triggers the JS that handles the progressive updating of the navigation
    ## buttons
    runjs(toggleButtons)
    
    {
    ## This bit references a pair of .Rmd files that can produce either
    ## .html or .png reports from the dashbaord. The .html files are especially
    ## useful as they are self-contained and maintain interactivity.
      
    ## Produce the filename
    dlName <- paste(gsub(' ', '_', gsub(',', '', tolower(isolate(rv$row[3])))),
                    '_', isolate(uv$dom), '_aqreport', sep = ''
    )
    ## If the user clicks on the HTML report button...
    output$report1 <- downloadHandler(
      ## Append the proper file extension
      filename = function(){
        paste(dlName, '.html', sep = '')
      },
      content = function(file){
        ## Use the report.Rmd file to create HTML output
        rmarkdown::render('report.Rmd',
          output_file = file,
          ## Pass these parameters to that file via the YAML header there
          params = list(dom = isolate(uv$dom),
                        patFIN = as.character(isolate(rv$row)[1]),
                        patMRN = as.character(isolate(rv$row)[2]),
                        patName = capFirst(as.character(isolate(rv$row)[3])),
                        patMS = as.character(isolate(rv$row)[4]),
                        patCMG = as.character(isolate(rv$row)[5]),
                        patFloor = as.character(isolate(rv$row)[6]),
                        patAdmit = isolate(rv$row)[7],
                        patAP = as.character(isolate(rv$row)[8]),
                        sg = ifelse(isolate(rv$scgroup) == 1,
                                    'Sitting Balance',
                                    ifelse(isolate(rv$scgroup) == 2,
                                           'Standing Balance',
                                           'Walking Balance'
                        )),
                        mg = ifelse(isolate(rv$mobgroup) == 1, 'Wheelchair',
                                    ifelse(isolate(rv$mobgroup) == 2,
                                           'Both', 'Walk'
                        )),
                        cg = ifelse(isolate(rv$coggroup) == 1, 'Aphasia',
                                    ifelse(isolate(rv$coggroup) == 2,
                                           'Cognitive-Communication Deficits',
                                    ifelse(isolate(rv$coggroup) == 3,
                                      'Cognitive-Communication Deficits (BI)',
                                    ifelse(isolate(rv$coggroup) == 4,
                                      'Cognitive-Communication Deficits (RHD)',
                                    ifelse(isolate(rv$coggroup) == 5,
                                      'Speech Disorder', NA
                        ))))),
                        checkGoalsSC = isolate(rv$fin) %in% fimSCGoals$FIN,
                        checkGoalsMob = isolate(rv$fin) %in% fimMobGoals$FIN,
                        checkGoalsCog = isolate(rv$fin) %in% fimCogGoals$FIN,
                        nullScoSC = !is.null(isolate(rv$scSco[[2]])),
                        nullScoMob = !is.null(isolate(rv$mobSco[[2]])),
                        nullScoCog = !is.null(isolate(rv$cogSco[[2]])),
                        fimPlot = isolate(rv$fimPlot),
                        toPlot = isolate(rv$toPlot),
                        predPlotFull = isolate(rv$predPlotFull),
                        xAx2 = rv$xAx2,
                        yAx2 = rv$yAx2,
                        balwlk = if(rv$mobgroup == 1 && !is.na(rv$mobgroup))
                                    'AQ - Balance'
                                 else
                                    'AQ - Balance/Walking',
                        coggroup = !is.na(isolate(rv$coggroup)),
                        tlData = isolate(tv$tlData),
                        groups = isolate(tv$groups)
          ),
          envir = parent.frame()
        )
      }
    )
    
    ## If the user clicks on the PNG report button...
    output$report2 <- downloadHandler(
      filename = function(){
        paste(dlName, '.png', sep = '')
      },
      content = function(file){
        # tempFold <- tempdir()
        # tempReport <- file.path(tempFold, 'report2.Rmd')
        # sralabLogo <- file.path(tempFold, 'sralabLogo.png')
        # file.copy('report2.Rmd', tempReport, overwrite = T)
        # file.copy('sralabLogo.png', sralabLogo, overwrite = T)
        rmarkdown::render('report2.Rmd',
          params = list(dom = isolate(uv$dom),
                        patFIN = as.character(isolate(rv$row)[1]),
                        patMRN = as.character(isolate(rv$row)[2]),
                        patName = capFirst(as.character(isolate(rv$row)[3])),
                        patMS = as.character(isolate(rv$row)[4]),
                        patCMG = as.character(isolate(rv$row)[5]),
                        patFloor = as.character(isolate(rv$row)[6]),
                        patAdmit = isolate(rv$row)[7],
                        patAP = as.character(isolate(rv$row)[8]),
                        sg = ifelse(isolate(rv$scgroup) == 1,
                                    'Sitting Balance',
                                    ifelse(isolate(rv$scgroup) == 2,
                                           'Standing Balance',
                                           'Walking Balance'
                        )),
                        mg = ifelse(isolate(rv$mobgroup) == 1, 'Wheelchair',
                                    ifelse(isolate(rv$mobgroup) == 2,
                                           'Both', 'Walk'
                        )),
                        cg = ifelse(isolate(rv$coggroup) == 1, 'Aphasia',
                                    ifelse(isolate(rv$coggroup) == 2,
                                           'Cognitive-Communication Deficits',
                                    ifelse(isolate(rv$coggroup) == 3,
                                      'Cognitive-Communication Deficits (BI)',
                                    ifelse(isolate(rv$coggroup) == 4,
                                      'Cognitive-Communication Deficits (RHD)',
                                    ifelse(isolate(rv$coggroup) == 5,
                                      'Speech Disorder', NA
                        ))))),
                        checkGoalsSC = isolate(rv$fin) %in% fimSCGoals$FIN,
                        checkGoalsMob = isolate(rv$fin) %in% fimMobGoals$FIN,
                        checkGoalsCog = isolate(rv$fin) %in% fimCogGoals$FIN,
                        nullScoSC = !is.null(isolate(rv$scSco[[2]])),
                        nullScoMob = !is.null(isolate(rv$mobSco[[2]])),
                        nullScoCog = !is.null(isolate(rv$cogSco[[2]])),
                        fimPlot = isolate(rv$fimPlot),
                        toPlot = isolate(rv$toPlot),
                        predPlotFull = isolate(rv$predPlotFull),
                        xAx2 = rv$xAx2,
                        yAx2 = rv$yAx2,
                        balwlk = if(rv$mobgroup == 1 && !is.na(rv$mobgroup))
                                    'AQ - Balance'
                                 else
                                    'AQ - Balance/Walking',
                        coggroup = !is.na(isolate(rv$coggroup)),
                        tlData = isolate(tv$tlData),
                        groups = isolate(tv$groups)
          ),
          envir = parent.frame()
        )
        ## Although that was, of course, still an HTML file, webshot converts
        ## it to an image.
        webshot(url = 'report2.html',
                file = file,
                zoom = .75, expand = c(0, 20, 0, 20)
        )
        file.remove('report2.html')
      }
    )
    } # download handlers
    
  })      # End event observer for datatable
  
  {
  ## The shinyjs enabled event handlers for various dashboard elements
    
  ## These change the domain
  onclick('scButton', changeDom('sc'))
  onclick('mobButton', changeDom('mob'))
  onclick('cogButton', changeDom('cog'))
  ## These cause the proper plots to be charted
  onclick(id = 'scButton', renderDisplay(), add = T)
  onclick(id = 'mobButton', renderDisplay(), add = T)
  onclick(id = 'cogButton', renderDisplay(), add = T)
  ## These rerun the currently displayed plots after the user has made changes
  ## to things like goals or groups
  onclick(id = 'updateITC_sc', updateHandler(), add = T)
  onclick(id = 'updateITC_mob', updateHandler(), add = T)
  onclick(id = 'updateITC_cog', updateHandler(), add = T)
  ## Resets plots to inital states
  onclick(id = 'resetITC_sc', resetHandler(), add = T)
  onclick(id = 'resetITC_mob', resetHandler(), add = T)
  onclick(id = 'resetITC_cog', resetHandler(), add = T)
  ## Updates the timeline
  onclick(id = 'updateTL', updateHandler2(), add = T)
  ## Runs the Help demo
  onclick(id = 'help', intro(), add = T)
  ## Reruns Goal and TRC plots after making edits to FIM data
  onclick('fimButton', updateFIM())
  ## Disables the Update FIM button when the patient doesn't have a cognition
  ## group.
  observe({
    toggleState('fimButton',
                condition = (uv$dom != 'cog' ||
                             !((rv$coggroup == 'Other') %in% c(NA, T))
                )
    )
  })
  ## Allows users to remove select assessment areas from displaying when not
  ## relevant to the patient.
  onclick(id = 'swl_ad', swl_switch())
  onclick(id = 'wc_ad', wc_switch())
  }   # shinyjs event handlers

  ## Causes R to stop running when the dashboard is closed. You'd think that's
  ## how it should work anyway, but unfortunately, that isn't the case.
  session$onSessionEnded(function() {
    stopApp()
  })

}         # End server file
