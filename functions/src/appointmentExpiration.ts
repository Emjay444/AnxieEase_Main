import { database, logger } from 'firebase-functions/v1';
import { initializeApp } from 'firebase-admin/app';
import { getDatabase } from 'firebase-admin/database';
import { createClient } from '@supabase/supabase-js';

// Initialize Firebase Admin
const app = initializeApp();
const realtimeDb = getDatabase(app);

// Initialize Supabase
const supabaseUrl = process.env.SUPABASE_URL!;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY!;
const supabase = createClient(supabaseUrl, supabaseServiceKey);

/**
 * Cloud Function to automatically expire pending appointments past deadline
 * Triggers: 
 * 1. Scheduled (every hour) to check all pending appointments
 * 2. Manual trigger for immediate expiration check
 */

/**
 * Scheduled function that runs every hour to check for expired appointments
 */
export const checkExpiredAppointments = database.ref('/trigger_appointment_expiration').onWrite(async (change: any, context: any) => {
  logger.info('🕐 Starting scheduled appointment expiration check...');
  
  try {
    const result = await expireOverdueAppointments();
    logger.info(`✅ Appointment expiration check completed. Expired: ${result.expiredCount}, Errors: ${result.errorCount}`);
    return result;
  } catch (error: any) {
    logger.error('❌ Error in scheduled appointment expiration check:', error);
    throw error;
  }
});

/**
 * HTTP trigger for manual appointment expiration check
 */
export const expireAppointmentsNow = database.ref('/manual_expire_appointments').onWrite(async (change: any, context: any) => {
  logger.info('🔧 Manual appointment expiration check triggered...');
  
  try {
    const result = await expireOverdueAppointments();
    logger.info(`✅ Manual appointment expiration completed. Expired: ${result.expiredCount}, Errors: ${result.errorCount}`);
    return {
      success: true,
      ...result
    };
  } catch (error: any) {
    logger.error('❌ Error in manual appointment expiration:', error);
    return {
      success: false,
      error: error.message,
      expiredCount: 0,
      errorCount: 1
    };
  }
});

/**
 * Core function to expire overdue appointments
 * Deadline Rule: Pending appointments expire 24 hours after creation
 * Example: Request on Oct 4 → Expires on Oct 5 (next day)
 */
async function expireOverdueAppointments(): Promise<{
  expiredCount: number;
  errorCount: number;
  details: Array<{ id: string; status: 'expired' | 'error'; error?: string }>;
}> {
  const now = new Date();
  const cutoffTime = new Date(now.getTime() - 24 * 60 * 60 * 1000); // 24 hours ago
  
  logger.info(`🔍 Checking for appointments created before: ${cutoffTime.toISOString()}`);
  
  try {
    // Query pending appointments that are past the deadline
    const { data: pendingAppointments, error: queryError } = await supabase
      .from('appointments')
      .select('*')
      .eq('status', 'pending')
      .lt('created_at', cutoffTime.toISOString());

    if (queryError) {
      logger.error('❌ Error querying pending appointments:', queryError);
      throw new Error(`Failed to query appointments: ${queryError.message}`);
    }

    if (!pendingAppointments || pendingAppointments.length === 0) {
      logger.info('ℹ️ No pending appointments found past deadline');
      return {
        expiredCount: 0,
        errorCount: 0,
        details: []
      };
    }

    logger.info(`📋 Found ${pendingAppointments.length} appointments to expire`);

    let expiredCount = 0;
    let errorCount = 0;
    const details: Array<{ id: string; status: 'expired' | 'error'; error?: string }> = [];

    // Process each overdue appointment
    for (const appointment of pendingAppointments) {
      try {
        logger.info(`⏰ Expiring appointment ${appointment.id} (created: ${appointment.created_at})`);
        
        // Update appointment status to expired
        const { error: updateError } = await supabase
          .from('appointments')
          .update({
            status: 'expired',
            response_message: `Appointment request expired after 24-hour deadline. Created on ${new Date(appointment.created_at).toLocaleDateString()}, expired on ${now.toLocaleDateString()}.`,
            updated_at: now.toISOString()
          })
          .eq('id', appointment.id);

        if (updateError) {
          logger.error(`❌ Error updating appointment ${appointment.id}:`, updateError);
          errorCount++;
          details.push({
            id: appointment.id,
            status: 'error',
            error: updateError.message
          });
        } else {
          logger.info(`✅ Successfully expired appointment ${appointment.id}`);
          expiredCount++;
          details.push({
            id: appointment.id,
            status: 'expired'
          });

          // Optional: Create a notification for the user about expiration
          try {
            await createExpirationNotification(appointment);
          } catch (notifError) {
            logger.warn(`⚠️ Failed to create expiration notification for appointment ${appointment.id}:`, notifError);
            // Don't fail the whole operation for notification errors
          }
        }
      } catch (error: any) {
        logger.error(`❌ Error processing appointment ${appointment.id}:`, error);
        errorCount++;
        details.push({
          id: appointment.id,
          status: 'error',
          error: error.message
        });
      }
    }

    // Log summary
    logger.info(`📊 Expiration summary:`);
    logger.info(`   ✅ Expired: ${expiredCount}`);
    logger.info(`   ❌ Errors: ${errorCount}`);
    logger.info(`   📋 Total processed: ${pendingAppointments.length}`);

    return {
      expiredCount,
      errorCount,
      details
    };

  } catch (error) {
    logger.error('❌ Critical error in expireOverdueAppointments:', error);
    throw error;
  }
}

/**
 * Create a notification for the user about appointment expiration
 */
async function createExpirationNotification(appointment: any): Promise<void> {
  try {
    const { error } = await supabase
      .from('notifications')
      .insert({
        user_id: appointment.user_id,
        title: 'Appointment Request Expired',
        message: `Your appointment request from ${new Date(appointment.created_at).toLocaleDateString()} has expired after 24 hours. Please submit a new request if you still need an appointment.`,
        type: 'info',
        related_screen: 'psychologist_profile',
        created_at: new Date().toISOString()
      });

    if (error) {
      logger.warn(`⚠️ Failed to create expiration notification for user ${appointment.user_id}:`, error);
    } else {
      logger.info(`📬 Created expiration notification for user ${appointment.user_id}`);
    }
  } catch (error) {
    logger.warn(`⚠️ Error creating expiration notification:`, error);
  }
}

/**
 * Utility function to manually trigger expiration for testing
 * This can be called from admin panel or debugging
 */
export async function triggerAppointmentExpiration(): Promise<void> {
  logger.info('🔧 Manual trigger: Appointment expiration starting...');
  
  try {
    // Write to Firebase to trigger the function
    const triggerRef = realtimeDb.ref('/manual_expire_appointments');
    await triggerRef.set({
      triggeredAt: new Date().toISOString(),
      triggeredBy: 'manual_call'
    });
    
    logger.info('✅ Manual trigger: Appointment expiration initiated');
  } catch (error: any) {
    logger.error('❌ Manual trigger: Error triggering appointment expiration:', error);
    throw error;
  }
}

// Export the main expiration function for use in other modules
export { expireOverdueAppointments };