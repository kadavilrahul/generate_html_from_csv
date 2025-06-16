// CONSTANTS

const URL_API = "http://localhost:5000";

//Bot pop-up intro
document.addEventListener("DOMContentLoaded", function () {
  var elemsTap = document.querySelector(".tap-target");
  var instancesTap = M.TapTarget.init(elemsTap, {});
  instancesTap.open();
  setTimeout(function () {
    instancesTap.close();
  }, 4000);
});

//initialization
$(document).ready(function () {
  //Bot pop-up intro
  $("div").removeClass("tap-target-origin");

  //drop down menu for close, restart conversation & clear the chats.
  $(".dropdown-trigger").dropdown();

  //initiate the modal for displaying the charts, if you dont have charts, then you comment the below line
  $(".modal").modal();
  // Show chatbot when profile icon is clicked
  $("#profile_div").click(function () {
    $(".widget").fadeIn(); // Show with animation
    $("#profile_div").hide(); // Hide the profile icon
  });

  //enable this if u have configured the bot to start the conversation.
  // showBotTyping();
  // $("#userInput").prop('disabled', true);

  //global variables
  cid = random(0, 100).toString();
  action_name = "action_greet_user";
  sender_id = "prince"+cid;

  //if you want the bot to start the conversation
  // custom_action_trigger();

  // Add welcome message
  setBotResponse({ result: "Hey! Curious about products, tracking an order, or need info fast? Just ask!" });
});

function random(min, max) {
    return Math.floor((Math.random() * (max - min + 1)) + min);
}

// ========================== restart conversation ========================
function restartConversation() {
  $("#userInput").prop("disabled", true);
  //destroy the existing chart
  $(".collapsible").remove();

  if (typeof chatChart !== "undefined") {
    chatChart.destroy();
  }

  $(".chart-container").remove();
  if (typeof modalChart !== "undefined") {
    modalChart.destroy();
  }
  $(".chats").html("");
  $(".usrInput").val("");
  send("/restart");
}

// ========================== let the bot start the conversation ========================
function action_trigger() {
  // send an event to the bot, so that bot can start the conversation by greeting the user
  $.ajax({
    url: `${URL_API}/message`,
    type: "GET",
    data: {
      name: action_name,
      policy: "MappingPolicy",
      confidence: "0.98",
    },
    success: function (botResponse, status) {
      console.log("Response from Rasa: ", botResponse, "\nStatus: ", status);

      if (botResponse.hasOwnProperty("messages")) {
        setBotResponse(botResponse.messages);
      }
      $("#userInput").prop("disabled", false);
    },
    error: function (xhr, textStatus, errorThrown) {
      // if there is no response from rasa server
      setBotResponse("");
      console.log("Error from bot end: ", textStatus);
      $("#userInput").prop("disabled", false);
    },
  });
}

// ========================== let the bot start the conversation ========================
function custom_action_trigger() {
  // send an event to the bot, so that bot can start the conversation by greeting the user
  $.ajax({
    url: `${URL_API}/message`,
    type: "GET",
    data: {
      next_action: action_name,
      tracker: {
        sender_id: sender_id,
      },
    },
    success: function (botResponse, status) {
      console.log("Response from Rasa: ", botResponse, "\nStatus: ", status);

      if (botResponse.hasOwnProperty("responses")) {
        setBotResponse(botResponse.responses);
      }
      $("#userInput").prop("disabled", false);
    },
    error: function (xhr, textStatus, errorThrown) {
      // if there is no response from rasa server
      setBotResponse("");
      console.log("Error from bot end: ", textStatus);
      $("#userInput").prop("disabled", false);
    },
  });
}

//=====================================	user enter or sends the message =====================
$(".usrInput").on("keyup keypress", function (e) {
  var keyCode = e.keyCode || e.which;

  var text = $(".usrInput").val();
  if (keyCode === 13) {
    if (text == "" || $.trim(text) == "") {
      e.preventDefault();
      return false;
    } else {
      //destroy the existing chart, if yu are not using charts, then comment the below lines
 /*     $(".collapsible").remove();
      if (typeof chatChart !== "undefined") {
        chatChart.destroy();
      }

      $(".chart-container").remove();
      if (typeof modalChart !== "undefined") {
        modalChart.destroy();
      } */

      $("#paginated_cards").remove();
      $(".suggestions").remove();
      $(".quickReplies").remove();
      $(".usrInput").blur();
      setUserResponse(text);
      send(text);
      e.preventDefault();
      return false;
    }
  }
});

$("#sendButton").on("click", function (e) {
  var text = $(".usrInput").val();
  console.log(text);
  if (text == "" || $.trim(text) == "") {
    e.preventDefault();
    return false;
  } else {
    //destroy the existing chart
    /*
    chatChart.destroy();
    $(".chart-container").remove();
    if (typeof modalChart !== "undefined") {
      modalChart.destroy();
    }
    */
    $(".suggestions").remove();
    $("#paginated_cards").remove();
    $(".quickReplies").remove();
    $(".usrInput").blur();
    setUserResponse(text);
    send(text);
    e.preventDefault();
    return false;
  }
});

//==================================== Set user response =====================================
function setUserResponse(message) {
  var UserResponse =
    '<div class="msgRow">' +
      '<p class="userMsg">' + message + '</p>' +
      '<img class="userAvatar" src="img/userAvatar_old.jpg">' +
    '</div>';
    
  $(UserResponse).appendTo(".chats").show("slow");

  $(".usrInput").val("");
  scrollToBottomOfResults();
  showBotTyping();
  $(".suggestions").remove();
}

//=========== Scroll to the bottom of the chats after new message has been added to chat ======
function scrollToBottomOfResults() {
  var terminalResultsDiv = document.getElementById("chats");
  terminalResultsDiv.scrollTop = terminalResultsDiv.scrollHeight;
}

//============== send the user message to rasa server =============================================
function send(message) {
  $.ajax({
     url: `${URL_API}/message?input=`+message,
    type: "GET",
    data: { input: message},
    success: function (botResponse, status) {
      console.log("Response from Rasa: ", botResponse, "\nStatus: ", status);

      // if user wants to restart the chat and clear the existing chat contents
      if (message.toLowerCase() == "/restart") {
        $("#userInput").prop("disabled", false);

        //if you want the bot to start the conversation after restart
        // custom_action_tigger();
        return;
      }
      setBotResponse(botResponse);
    },
    error: function (xhr, textStatus, errorThrown) {
      if (message.toLowerCase() == "/restart") {
        // $("#userInput").prop('disabled', false);
        //if you want the bot to start the conversation after the restart action.
        // action_trigger();
        // return;
      }

      // if there is no response from rasa server
      setBotResponse("");
      console.log("Error from bot end: ", textStatus);
    },
  });
}

//=================== set bot response in the chats ===========================================
function setBotResponse(response) {
  //display bot response after 500 milliseconds
  setTimeout(function () {
    hideBotTyping();
    if (response.length < 1) {
      //if there is no response from Rasa, send  fallback message to the user
      var fallbackMsg = "I'm having some problems, if this happens again, click on the Menu and restart!";

      var BotResponse =
      '<div class="msgRow">' +
        '<p class="botMsg">' + fallbackMsg + '</p>' +
        '<img class="botAvatar" src="img/botAvatar_old.png"/>' +
      '</div>';
    

      $(BotResponse).appendTo(".chats").hide().fadeIn(1000);
      scrollToBottomOfResults();
    } else {
      //if we get response from Rasa
      //for (i = 0; i < response.length; i++) {
        //check if the response contains "text"
        if (response.hasOwnProperty("result")) {
          if (response.result != null) {
            var contentMsg = response.result.replace(/\n/g, "<br />");
            var BotResponse =
              '<img class="botAvatar" src="img/botAvatar_old.png"/><p class="botMsg">' +
              contentMsg +
              '</p><div class="clearfix"></div>';
            $(BotResponse).appendTo(".chats").hide().fadeIn(1000);
          }
        }
/**
        //check if the response contains "images"
        if (response[i].hasOwnProperty("image")) {
          if (response[i].image !== null) {
            var BotResponse =
              '<div class="singleCard">' +
              '<img class="imgcard" src="' +
              response[i].image +
              '">' +
              '</div><div class="clearfix">';
            $(BotResponse).appendTo(".chats").hide().fadeIn(1000);
          }
        }

        //check if the response contains "buttons"
        if (response[i].hasOwnProperty("buttons")) {
          if (response[i].buttons.length > 0) {
            addSuggestion(response[i].buttons);
          }
        }

        //check if the response contains "attachment"
        if (response[i].hasOwnProperty("attachment")) {
          if (response[i].attachment != null) {
            if (response[i].attachment.type == "video") {
              //check if the attachment type is "video"
              video_url = response[i].attachment.payload.src;

              var BotResponse =
                '<div class="video-container"> <iframe src="' +
                video_url +
                '" frameborder="0" allowfullscreen></iframe> </div>';
              $(BotResponse).appendTo(".chats").hide().fadeIn(1000);
            }
          }
        }
        //check if the response contains "custom" message
        if (response[i].hasOwnProperty("custom")) {
          if (response[i].custom.payload == "quickReplies") {
            //check if the custom payload type is "quickReplies"
            quickRepliesData = response[i].custom.data;
            showQuickReplies(quickRepliesData);
            return;
          }

          //check if the custom payload type is "pdf_attachment"
          if (response[i].custom.payload == "pdf_attachment") {
            renderPdfAttachment(response[i]);
            return;
          }

          //check if the custom payload type is "dropDown"
          if (response[i].custom.payload == "dropDown") {
            dropDownData = response[i].custom.data;
            renderDropDwon(dropDownData);
            return;
          }

          //check if the custom payload type is "location"
          if (response[i].custom.payload == "location") {
            $("#userInput").prop("disabled", true);
            getLocation();
            scrollToBottomOfResults();
            return;
          }

          //check if the custom payload type is "cardsCarousel"
          if (response[i].custom.payload == "cardsCarousel") {
            restaurantsData = response[i].custom.data;
            showCardsCarousel(restaurantsData);
            return;
          }

          //check if the custom payload type is "chart"
          if (response[i].custom.payload == "chart") {
            // sample format of the charts data:
            // var chartData = { "title": "Leaves", "labels": ["Sick Leave", "Casual Leave", "Earned Leave", "Flexi Leave"], "backgroundColor": ["#36a2eb", "#ffcd56", "#ff6384", "#009688", "#c45850"], "chartsData": [5, 10, 22, 3], "chartType": "pie", "displayLegend": "true" }

            //store the below parameters as global variable,
            // so that it can be used while displaying the charts in modal.
            chartData = response[i].custom.data;
            title = chartData.title;
            labels = chartData.labels;
            backgroundColor = chartData.backgroundColor;
            chartsData = chartData.chartsData;
            chartType = chartData.chartType;
            displayLegend = chartData.displayLegend;

            // pass the above variable to createChart function
            createChart(
              title,
              labels,
              backgroundColor,
              chartsData,
              chartType,
              displayLegend
            );
            return;
          }

          //check of the custom payload type is "collapsible"
          if (response[i].custom.payload == "collapsible") {
            data = response[i].custom.data;
            //pass the data variable to createCollapsible function
            createCollapsible(data);
          }
        }
		**/
      //}
      scrollToBottomOfResults();
	  $("#userInput").focus();
    }
  }, 10);
}

//====================================== Toggle chatbot =======================================

//====================================== Render Pdf attachment =======================================
function renderPdfAttachment(data) {
  pdf_url = data.custom.url;
  pdf_title = data.custom.title;
  pdf_attachment =
    '<div class="pdf_attachment">' +
    '<div class="row">' +
    '<div class="col s3 pdf_icon"><i class="fa fa-file-pdf-o" aria-hidden="true"></i></div>' +
    '<div class="col s9 pdf_link">' +
    '<a href="' +
    pdf_url +
    '" target="_blank">' +
    pdf_title +
    " </a>" +
    "</div>" +
    "</div>" +
    "</div>";
  $(".chats").append(pdf_attachment);
  scrollToBottomOfResults();
}

//====================================== DropDown ==================================================
//render the dropdown messageand handle user selection
// Corrected function name (was "renderDropDwon")
function renderDropdown(data) {
  // Clear previous dropdowns
  $('.dropDownMsg').remove();
  
  // Create options
  const options = data.map(item => 
      `<option value="${item.value}">${item.label}</option>`
  ).join('');
  
  // Create dropdown HTML
  const dropdown = `
      <div class="dropDownMsg">
          <select class="browser-default dropDownSelect">
              <option value="" disabled selected>Choose option...</option>
              ${options}
          </select>
      </div>
  `;
  
  // Append to chat
  $('#chats').append(dropdown);
  
  // Add event handler
  $('.dropDownSelect').off('change').on('change', function() {
      const selected = $(this).find('option:selected');
      setUserResponse(selected.text());
      send(selected.val());
      $(this).closest('.dropDownMsg').remove();
  });
  
  scrollToBottomOfResults();
}
//====================================== Suggestions ===========================================

function addSuggestion(textToAdd) {
  setTimeout(function () {
    var suggestions = textToAdd;
    var suggLength = textToAdd.length;
    $(
      ' <div class="singleCard"> <div class="suggestions"><div class="menu"></div></div></diV>'
    )
      .appendTo(".chats")
      .hide()
      .fadeIn(1000);
    // Loop through suggestions
    for (i = 0; i < suggLength; i++) {
      $(
        '<div class="menuChips" data-payload=\'' +
          suggestions[i].payload +
          "'>" +
          suggestions[i].title +
          "</div>"
      ).appendTo(".menu");
    }
    scrollToBottomOfResults();
  }, 1000);
}

// on click of suggestions, get the value and send to rasa
$(document).on("click", ".menu .menuChips", function () {
  var text = this.innerText;
  var payload = this.getAttribute("data-payload");
  console.log("payload: ", this.getAttribute("data-payload"));
  setUserResponse(text);
  send(payload);

  //delete the suggestions once user click on it
  $(".suggestions").remove();
});

//====================================== functions for drop-down menu of the bot  =========================================

//restart function to restart the conversation.
$("#restart").click(function () {
  restartConversation();
});

//clear function to clear the chat contents of the widget.
$("#clear").click(function () {
  $(".chats").fadeOut("normal", function () {
    $(".chats").html("");
    $(".chats").fadeIn();
  });
});

//close function to close the widget.
$("#close").click(function () {
  $(".profile_div").toggle();
  $(".widget").toggle();
  scrollToBottomOfResults();
});

//close function for the close button in the header
$(".close-button").click(function () {
  $(".profile_div").toggle();
  $(".widget").toggle();
  scrollToBottomOfResults();
});

//====================================== Cards Carousel =========================================

function showCardsCarousel(cardsToAdd) {
  var cards = createCardsCarousel(cardsToAdd);

  $(cards).appendTo(".chats").show();

  if (cardsToAdd.length <= 2) {
    $(".cards_scroller>div.carousel_cards:nth-of-type(" + i + ")").fadeIn(3000);
  } else {
    for (var i = 0; i < cardsToAdd.length; i++) {
      $(".cards_scroller>div.carousel_cards:nth-of-type(" + i + ")").fadeIn(
        3000
      );
    }
    $(".cards .arrow.prev").fadeIn("3000");
    $(".cards .arrow.next").fadeIn("3000");
  }

  scrollToBottomOfResults();

  const card = document.querySelector("#paginated_cards");
  const card_scroller = card.querySelector(".cards_scroller");
  var card_item_size = 225;

  card.querySelector(".arrow.next").addEventListener("click", scrollToNextPage);
  card.querySelector(".arrow.prev").addEventListener("click", scrollToPrevPage);

  // For paginated scrolling, simply scroll the card one item in the given
  // direction and let css scroll snaping handle the specific alignment.
  function scrollToNextPage() {
    card_scroller.scrollBy(card_item_size, 0);
  }

  function scrollToPrevPage() {
    card_scroller.scrollBy(-card_item_size, 0);
  }
}

function createCardsCarousel(cardsData) {
  var cards = "";

  for (i = 0; i < cardsData.length; i++) {
    title = cardsData[i].name;
    ratings = Math.round((cardsData[i].ratings / 5) * 100) + "%";
    data = cardsData[i];
    item =
      '<div class="carousel_cards in-left">' +
      '<img class="cardBackgroundImage" src="' +
      cardsData[i].image +
      '"><div class="cardFooter">' +
      '<span class="cardTitle" title="' +
      title +
      '">' +
      title +
      "</span> " +
      '<div class="cardDescription">' +
      '<div class="stars-outer">' +
      '<div class="stars-inner" style="width:' +
      ratings +
      '" ></div>' +
      "</div>" +
      "</div>" +
      "</div>" +
      "</div>";

    cards += item;
  }

  var cardContents =
    '<div id="paginated_cards" class="cards"> <div class="cards_scroller">' +
    cards +
    '  <span class="arrow prev fa fa-chevron-circle-left "></span> <span class="arrow next fa fa-chevron-circle-right" ></span> </div> </div>';

  return cardContents;
}

//====================================== Quick Replies ==================================================

function showQuickReplies(quickRepliesData) {
  var chips = "";
  for (i = 0; i < quickRepliesData.length; i++) {
    var chip =
      '<div class="chip" data-payload=\'' +
      quickRepliesData[i].payload +
      "'>" +
      quickRepliesData[i].title +
      "</div>";
    chips += chip;
  }

  var quickReplies =
    '<div class="quickReplies">' + chips + '</div><div class="clearfix"></div>';
  $(quickReplies).appendTo(".chats").fadeIn(1000);
  scrollToBottomOfResults();
  const slider = document.querySelector(".quickReplies");
  let isDown = false;
  let startX;
  let scrollLeft;

  slider.addEventListener("mousedown", (e) => {
    isDown = true;
    slider.classList.add("active");
    startX = e.pageX - slider.offsetLeft;
    scrollLeft = slider.scrollLeft;
  });
  slider.addEventListener("mouseleave", () => {
    isDown = false;
    slider.classList.remove("active");
  });
  slider.addEventListener("mouseup", () => {
    isDown = false;
    slider.classList.remove("active");
  });
  slider.addEventListener("mousemove", (e) => {
    if (!isDown) return;
    e.preventDefault();
    const x = e.pageX - slider.offsetLeft;
    const walk = (x - startX) * 3; //scroll-fast
    slider.scrollLeft = scrollLeft - walk;
  });
}

// on click of quickreplies, get the value and send to rasa
$(document).on("click", ".quickReplies .chip", function () {
  var text = this.innerText;
  var payload = this.getAttribute("data-payload");
  console.log("chip payload: ", this.getAttribute("data-payload"));
  setUserResponse(text);
  send(payload);

  //delete the quickreplies
  $(".quickReplies").remove();
});

//====================================== Get User Location ==================================================
function getLocation() {
  if (navigator.geolocation) {
    navigator.geolocation.getCurrentPosition(
      getUserPosition,
      handleLocationAccessError
    );
  } else {
    response = "Geolocation is not supported by this browser.";
  }
}

function getUserPosition(position) {
  response =
    "Latitude: " +
    position.coords.latitude +
    " Longitude: " +
    position.coords.longitude;
  console.log("location: ", response);

  //here you add the intent which you want to trigger
  response =
    '/inform{"latitude":' +
    position.coords.latitude +
    ',"longitude":' +
    position.coords.longitude +
    "}";
  $("#userInput").prop("disabled", false);
  send(response);
  showBotTyping();
}

function handleLocationAccessError(error) {
  switch (error.code) {
    case error.PERMISSION_DENIED:
      console.log("User denied the request for Geolocation.");
      break;
    case error.POSITION_UNAVAILABLE:
      console.log("Location information is unavailable.");
      break;
    case error.TIMEOUT:
      console.log("The request to get user location timed out.");
      break;
    case error.UNKNOWN_ERROR:
      console.log("An unknown error occurred.");
      break;
  }

  response = '/inform{"user_location":"deny"}';
  send(response);
  showBotTyping();
  $(".usrInput").val("");
  $("#userInput").prop("disabled", false);
}

//======================================bot typing animation ======================================
function showBotTyping() {
  var botTyping =
    '<img class="botAvatar" id="botAvatar" src="img/botAvatar_old.png"/><div class="botTyping">' +
    '<div class="bounce1"></div>' +
    '<div class="bounce2"></div>' +
    '<div class="bounce3"></div>' +
    "</div>";
  $(botTyping).appendTo(".chats");
  $(".botTyping").show();
  scrollToBottomOfResults();
}

function hideBotTyping() {
  $("#botAvatar").remove();
  $(".botTyping").remove();
}

//====================================== Collapsible =========================================

// function to create collapsible,
// for more info refer:https://materializecss.com/collapsible.html
function createCollapsible(data) {
  //sample data format:
  //var data=[{"title":"abc","description":"xyz"},{"title":"pqr","description":"jkl"}]
  list = "";
  for (i = 0; i < data.length; i++) {
    item =
      "<li>" +
      '<div class="collapsible-header">' +
      data[i].title +
      "</div>" +
      '<div class="collapsible-body"><span>' +
      data[i].description +
      "</span></div>" +
      "</li>";
    list += item;
  }
  var contents = '<ul class="collapsible">' + list + "</uL>";
  $(contents).appendTo(".chats");

  // initialize the collapsible
  $(".collapsible").collapsible();
  scrollToBottomOfResults();
}

//====================================== creating Charts ======================================

//function to create the charts & render it to the canvas
function createChart(
  title,
  labels,
  backgroundColor,
  chartsData,
  chartType,
  displayLegend
) {
  //create the ".chart-container" div that will render the charts in canvas as required by charts.js,
  // for more info. refer: https://www.chartjs.org/docs/latest/getting-started/usage.html
  var html =
    '<div class="chart-container"> <span class="modal-trigger" id="expand" title="expand" href="#modal1"><i class="fa fa-external-link" aria-hidden="true"></i></span> <canvas id="chat-chart" ></canvas> </div> <div class="clearfix"></div>';
  $(html).appendTo(".chats");

  //create the context that will draw the charts over the canvas in the ".chart-container" div
  var ctx = $("#chat-chart");

  // Once you have the element or context, instantiate the chart-type by passing the configuration,
  //for more info. refer: https://www.chartjs.org/docs/latest/configuration/
  var data = {
    labels: labels,
    datasets: [
      {
        label: title,
        backgroundColor: backgroundColor,
        data: chartsData,
        fill: false,
      },
    ],
  };
  var options = {
    title: {
      display: true,
      text: title,
    },
    layout: {
      padding: {
        left: 5,
        right: 0,
        top: 0,
        bottom: 0,
      },
    },
    legend: {
      display: displayLegend,
      position: "right",
      labels: {
        boxWidth: 5,
        fontSize: 10,
      },
    },
  };

  //draw the chart by passing the configuration
  chatChart = new Chart(ctx, {
    type: chartType,
    data: data,
    options: options,
  });

  scrollToBottomOfResults();
}

// on click of expand button, get the chart data from gloabl variable & render it to modal
$(document).on("click", "#expand", function () {
  //the parameters are declared gloabally while we get the charts data from rasa.
  createChartinModal(
    title,
    labels,
    backgroundColor,
    chartsData,
    chartType,
    displayLegend
  );
});

//function to render the charts in the modal
function createChartinModal(
  title,
  labels,
  backgroundColor,
  chartsData,
  chartType,
  displayLegend
) {
  //if you want to display the charts in modal, make sure you have configured the modal in index.html
  //create the context that will draw the charts over the canvas in the "#modal-chart" div of the modal
  var ctx = $("#modal-chart");

  // Once you have the element or context, instantiate the chart-type by passing the configuration,
  //for more info. refer: https://www.chartjs.org/docs/latest/configuration/
  var data = {
    labels: labels,
    datasets: [
      {
        label: title,
        backgroundColor: backgroundColor,
        data: chartsData,
        fill: false,
      },
    ],
  };
  var options = {
    title: {
      display: true,
      text: title,
    },
    layout: {
      padding: {
        left: 5,
        right: 0,
        top: 0,
        bottom: 0,
      },
    },
    legend: {
      display: displayLegend,
      position: "right",
    },
  };

  modalChart = new Chart(ctx, {
    type: chartType,
    data: data,
    options: options,
  });
}
