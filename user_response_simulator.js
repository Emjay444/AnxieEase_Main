#!/usr/bin/env node

/**
 * 📱 ANXIETY ALERT USER RESPONSE SIMULATOR
 * 
 * Shows what happens when users respond YES/NO/NOT NOW to different anxiety alerts
 */

const readline = require('readline');

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

console.log("📱 ANXIETY ALERT USER RESPONSE SIMULATOR");
console.log("=========================================\n");

console.log("🎯 PURPOSE: Simulate what happens when a user responds to anxiety alerts");
console.log("📱 CONTEXT: You received an anxiety notification and need to respond\n");

// Anxiety notification scenarios
const scenarios = {
  1: {
    severity: "mild",
    heartRate: 78,
    notification: {
      title: "🟢 Mild Anxiety Alert",
      body: "Slight elevation detected. HR: 78 BPM (20% above baseline)\nWe noticed some changes. Are you feeling anxious right now?"
    }
  },
  2: {
    severity: "moderate", 
    heartRate: 88,
    notification: {
      title: "🟡 Moderate Anxiety Alert",
      body: "Noticeable changes detected. HR: 88 BPM (35% above baseline)\nYour readings suggest possible anxiety. How are you feeling?"
    }
  },
  3: {
    severity: "severe",
    heartRate: 98, 
    notification: {
      title: "🟠 Severe Anxiety Alert",
      body: "Significant elevation detected. HR: 98 BPM (50% above baseline)\nURGENT: High anxiety detected. Please confirm your status."
    }
  },
  4: {
    severity: "critical",
    heartRate: 115,
    notification: {
      title: "🔴 CRITICAL Anxiety Alert", 
      body: "URGENT: Severe symptoms detected. HR: 115 BPM (77% above baseline)\nEMERGENCY: Critical anxiety level. Immediate assistance recommended."
    }
  }
};

function showScenarioMenu() {
  console.log("📱 SELECT ANXIETY ALERT SCENARIO:");
  console.log("==================================");
  
  Object.entries(scenarios).forEach(([key, scenario]) => {
    console.log(`${key}. ${scenario.notification.title}`);
    console.log(`   HR: ${scenario.heartRate} BPM`);
  });
  
  console.log("\nEnter scenario number (1-4): ");
}

function simulateNotification(scenarioNum) {
  const scenario = scenarios[scenarioNum];
  
  console.clear();
  console.log("📱 NOTIFICATION RECEIVED!");
  console.log("========================\n");
  
  console.log("┌─────────────────────────────────────────┐");
  console.log("│              📱 AnxieEase               │");
  console.log("├─────────────────────────────────────────┤");
  console.log(`│ ${scenario.notification.title.padEnd(39)} │`);
  console.log("├─────────────────────────────────────────┤");
  
  const bodyLines = scenario.notification.body.split('\n');
  bodyLines.forEach(line => {
    // Split long lines
    while (line.length > 39) {
      console.log(`│ ${line.substr(0, 39)} │`);
      line = line.substr(39);
    }
    if (line.length > 0) {
      console.log(`│ ${line.padEnd(39)} │`);
    }
  });
  
  console.log("├─────────────────────────────────────────┤");
  console.log("│                                         │");
  console.log("│  [1] ✅ YES - I'm feeling anxious      │");
  console.log("│  [2] ❌ NO - False alarm               │");
  console.log("│  [3] ⏸️  NOT NOW - Remind me later     │");
  console.log("│  [4] 🔇 IGNORE - Dismiss               │");
  console.log("│                                         │");
  console.log("└─────────────────────────────────────────┘\n");
  
  return new Promise((resolve) => {
    rl.question("How do you respond? (1-4): ", (answer) => {
      resolve({ scenario, response: parseInt(answer) });
    });
  });
}

function showUserResponseResult(scenario, response) {
  console.clear();
  console.log("⚡ SYSTEM RESPONSE");
  console.log("=================\n");
  
  const responses = {
    1: { // YES
      icon: "✅",
      action: "ANXIETY CONFIRMED",
      immediate: [
        "🫁 Breathing Exercise Launched",
        "   'Let's take 5 deep breaths together...'",
        "   [▶️ Start 4-7-8 Breathing]",
        "",
        "🧘 Grounding Techniques Available", 
        "   • 5-4-3-2-1 Sensory grounding",
        "   • Progressive muscle relaxation",
        "   • Mindfulness meditation",
        ""
      ],
      severe_critical: [
        "📞 Emergency Contacts Displayed",
        "   👥 Family: Call Mom, Call Dad", 
        "   🏥 Healthcare: Dr. Smith",
        "   🆘 Crisis Line: 988",
        "",
        "🚨 Emergency Options",
        "   [📞 Call 911] [🏥 Find Hospital]",
        ""
      ],
      followup: [
        "⏰ Follow-up Scheduled",
        `   ${scenario.severity === 'critical' ? '5' : scenario.severity === 'severe' ? '10' : '30'} minute check-in`,
        "",
        "📊 Data Updated:",
        "   • Anxiety event confirmed",
        "   • User pattern updated",
        "   • Detection sensitivity +5%"
      ]
    },
    2: { // NO  
      icon: "❌",
      action: "FALSE POSITIVE REPORTED",
      immediate: [
        "💡 Let's Figure Out What Happened",
        "   Were you:",
        "   • 🏃 Exercising or being active?",
        "   • ☕ Drinking caffeine or energy drinks?", 
        "   • 😤 Stressed about something else?",
        "   • 🔥 In a warm environment?",
        "",
        "⚙️ Sensitivity Adjustment",
        "   [🔧 Reduce Sensitivity] [📊 View History]"
      ],
      severe_critical: [],
      followup: [
        "⏰ Extended Cooldown Applied",
        "   Next check in 2 hours",
        "",
        "📊 Data Updated:",
        "   • False positive recorded",
        "   • Threshold increased by 5%", 
        "   • Algorithm learning improved"
      ]
    },
    3: { // NOT NOW
      icon: "⏸️",
      action: "REMINDER SCHEDULED", 
      immediate: [
        "💤 Snooze Options Selected",
        "   ⏰ Remind me in:",
        "   • 5 minutes",
        "   • 15 minutes ✓",
        "   • 1 hour", 
        "",
        "📱 Quick Check",
        "   On a scale of 1-10, how do you feel?",
        "   [1] [2] [3] [4] [5] [6] [7] [8] [9] [10]"
      ],
      severe_critical: [
        "🚨 High Priority Reminder",
        "   We'll check back in 5 minutes",
        "   Emergency help remains available",
        ""
      ],
      followup: [
        "⏰ Gentle Follow-up Set",
        "   'Just checking - how are you feeling?'",
        "",
        "📊 Data Updated:",
        "   • Deferred response logged",
        "   • No algorithm changes"
      ]
    },
    4: { // IGNORE
      icon: "🔇",
      action: "NOTIFICATION DISMISSED",
      immediate: [
        "🔕 Notification Cleared",
        "   We understand you're busy",
        "",
        "⏰ Gentle Follow-up",
        "   We'll check quietly in 5 minutes:",
        "   'Still monitoring your wellness 💚'"
      ],
      severe_critical: [
        "🚨 High Priority Follow-up",
        "   Critical alerts require attention",
        "   Follow-up in 2 minutes",
        ""
      ],
      followup: [
        "⏰ Background Monitoring", 
        "   Reduced notification frequency",
        "",
        "📊 Data Updated:",
        "   • Dismissed alert logged",
        "   • Sensitivity reduced -3%"
      ]
    }
  };
  
  const userResponse = responses[response];
  if (!userResponse) {
    console.log("❌ Invalid response selected");
    return;
  }
  
  console.log(`${userResponse.icon} ${userResponse.action}`);
  console.log("═".repeat(userResponse.action.length + 2));
  console.log("");
  
  // Show immediate response
  console.log("📱 IMMEDIATE APP RESPONSE:");
  console.log("--------------------------");
  userResponse.immediate.forEach(line => console.log(line));
  
  // Show severe/critical specific features
  if ((scenario.severity === 'severe' || scenario.severity === 'critical') && userResponse.severe_critical.length > 0) {
    console.log("🚨 EMERGENCY FEATURES ACTIVATED:");
    console.log("--------------------------------");
    userResponse.severe_critical.forEach(line => console.log(line));
  }
  
  // Show system follow-up
  console.log("🔄 SYSTEM FOLLOW-UP:");
  console.log("--------------------");
  userResponse.followup.forEach(line => console.log(line));
  
  console.log("\n" + "─".repeat(50));
}

async function runSimulation() {
  try {
    while (true) {
      showScenarioMenu();
      
      const scenarioChoice = await new Promise((resolve) => {
        rl.question("", (answer) => resolve(parseInt(answer)));
      });
      
      if (scenarioChoice < 1 || scenarioChoice > 4) {
        console.log("❌ Please select 1-4");
        continue;
      }
      
      const { scenario, response } = await simulateNotification(scenarioChoice);
      
      if (response < 1 || response > 4) {
        console.log("❌ Please select 1-4");
        await new Promise(resolve => setTimeout(resolve, 1000));
        continue;
      }
      
      showUserResponseResult(scenario, response);
      
      const continueChoice = await new Promise((resolve) => {
        rl.question("\n🔄 Try another scenario? (y/n): ", resolve);
      });
      
      if (continueChoice.toLowerCase() !== 'y') {
        break;
      }
      
      console.clear();
    }
    
    console.log("\n🎊 Thanks for testing the anxiety alert system!");
    console.log("Now you know how users interact with different severity levels! 🎊");
    
  } catch (error) {
    console.error("Error:", error);
  } finally {
    rl.close();
  }
}

// Start the simulation
runSimulation();