const tips = [
    "Press F1 to open the help menu once in-game!",
    "Remember to roleplay realistically at all times.",
    "Use /help to see available commands.",
    "Join our Discord for updates and community events!",
    "Report bugs or issues to help improve the server.",
    "Respect other players and follow server rules.",
    "Save your game progress regularly by logging out properly.",
    "Explore the city to discover hidden locations and activities!",
    "Make friends and build your criminal empire or law enforcement career.",
    "Your choices matter - think before you act!"
];

let currentTip = 0;

// Rotate tips
function rotateTips() {
    const tipElement = document.getElementById('tip');
    tipElement.style.opacity = '0';
    
    setTimeout(() => {
        currentTip = (currentTip + 1) % tips.length;
        tipElement.textContent = tips[currentTip];
        tipElement.style.opacity = '1';
    }, 500);
}

setInterval(rotateTips, 5000);

// Loading progress simulation
let progress = 0;
const progressFill = document.getElementById('progressFill');
const loadingText = document.getElementById('loadingText');
const loadingDetails = document.getElementById('loadingDetails');

const loadingStages = [
    { text: "Connecting to server...", detail: "Establishing connection...", progress: 10 },
    { text: "Loading resources...", detail: "Downloading game files...", progress: 30 },
    { text: "Initializing systems...", detail: "Setting up game world...", progress: 50 },
    { text: "Preparing character data...", detail: "Loading your profile...", progress: 70 },
    { text: "Almost ready...", detail: "Finalizing setup...", progress: 90 },
    { text: "Welcome to JCRP!", detail: "Entering the city...", progress: 100 }
];

let currentStage = 0;

// Listen for loading events from FiveM
const handlers = {
    startInitFunctionOrder(data) {
        updateLoading(0);
    },
    
    initFunctionInvoking(data) {
        updateLoading(Math.min(currentStage + 1, loadingStages.length - 1));
    },
    
    startDataFileEntries(data) {
        updateLoading(Math.min(currentStage + 1, loadingStages.length - 1));
    },
    
    performMapLoadFunction(data) {
        updateLoading(Math.min(currentStage + 1, loadingStages.length - 1));
    }
};

function updateLoading(stage) {
    if (stage >= loadingStages.length) {
        stage = loadingStages.length - 1;
    }
    
    currentStage = stage;
    const stageData = loadingStages[stage];
    
    loadingText.textContent = stageData.text;
    loadingDetails.textContent = stageData.detail;
    progressFill.style.width = stageData.progress + '%';
    
    // When loading is complete, trigger shutdown
    if (stageData.progress >= 100) {
        setTimeout(() => {
            window.invokeNative('shutdown', '');
        }, 2000);
    }
}

// Register handlers
window.addEventListener('message', function(e) {
    if (handlers[e.data.eventName]) {
        handlers[e.data.eventName](e.data);
    }
});

// Fallback progress animation
let fallbackProgress = 0;
setInterval(() => {
    if (fallbackProgress < 100) {
        fallbackProgress += 0.5;
        progressFill.style.width = fallbackProgress + '%';
        
        // Update stages based on progress
        if (fallbackProgress > 90) {
            updateLoading(5);
        } else if (fallbackProgress > 70) {
            updateLoading(4);
        } else if (fallbackProgress > 50) {
            updateLoading(3);
        } else if (fallbackProgress > 30) {
            updateLoading(2);
        } else if (fallbackProgress > 10) {
            updateLoading(1);
        }
    }
}, 100);
