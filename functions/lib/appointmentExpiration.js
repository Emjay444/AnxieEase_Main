"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.expireOverdueAppointments = exports.triggerAppointmentExpiration = exports.expireAppointmentsNow = exports.checkExpiredAppointments = void 0;
const v1_1 = require("firebase-functions/v1");
const app_1 = require("firebase-admin/app");
const database_1 = require("firebase-admin/database");
const supabase_js_1 = require("@supabase/supabase-js");
// Initialize Firebase Admin
const app = (0, app_1.initializeApp)();
const realtimeDb = (0, database_1.getDatabase)(app);
// Initialize Supabase
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;
const supabase = (0, supabase_js_1.createClient)(supabaseUrl, supabaseServiceKey);
/**
 * Cloud Function to automatically expire pending appointments past deadline
 * Triggers:
 * 1. Scheduled (every hour) to check all pending appointments
 * 2. Manual trigger for immediate expiration check
 */
/**
 * Scheduled function that runs every hour to check for expired appointments
 */
exports.checkExpiredAppointments = v1_1.database.ref('/trigger_appointment_expiration').onWrite(async (change, context) => {
    v1_1.logger.info('🕐 Starting scheduled appointment expiration check...');
    try {
        const result = await expireOverdueAppointments();
        v1_1.logger.info(`✅ Appointment expiration check completed. Expired: ${result.expiredCount}, Errors: ${result.errorCount}`);
        return result;
    }
    catch (error) {
        v1_1.logger.error('❌ Error in scheduled appointment expiration check:', error);
        throw error;
    }
});
/**
 * HTTP trigger for manual appointment expiration check
 */
exports.expireAppointmentsNow = v1_1.database.ref('/manual_expire_appointments').onWrite(async (change, context) => {
    v1_1.logger.info('🔧 Manual appointment expiration check triggered...');
    try {
        const result = await expireOverdueAppointments();
        v1_1.logger.info(`✅ Manual appointment expiration completed. Expired: ${result.expiredCount}, Errors: ${result.errorCount}`);
        return Object.assign({ success: true }, result);
    }
    catch (error) {
        v1_1.logger.error('❌ Error in manual appointment expiration:', error);
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
async function expireOverdueAppointments() {
    const now = new Date();
    const cutoffTime = new Date(now.getTime() - 24 * 60 * 60 * 1000); // 24 hours ago
    v1_1.logger.info(`🔍 Checking for appointments created before: ${cutoffTime.toISOString()}`);
    try {
        // Query pending appointments that are past the deadline
        const { data: pendingAppointments, error: queryError } = await supabase
            .from('appointments')
            .select('*')
            .eq('status', 'pending')
            .lt('created_at', cutoffTime.toISOString());
        if (queryError) {
            v1_1.logger.error('❌ Error querying pending appointments:', queryError);
            throw new Error(`Failed to query appointments: ${queryError.message}`);
        }
        if (!pendingAppointments || pendingAppointments.length === 0) {
            v1_1.logger.info('ℹ️ No pending appointments found past deadline');
            return {
                expiredCount: 0,
                errorCount: 0,
                details: []
            };
        }
        v1_1.logger.info(`📋 Found ${pendingAppointments.length} appointments to expire`);
        let expiredCount = 0;
        let errorCount = 0;
        const details = [];
        // Process each overdue appointment
        for (const appointment of pendingAppointments) {
            try {
                v1_1.logger.info(`⏰ Expiring appointment ${appointment.id} (created: ${appointment.created_at})`);
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
                    v1_1.logger.error(`❌ Error updating appointment ${appointment.id}:`, updateError);
                    errorCount++;
                    details.push({
                        id: appointment.id,
                        status: 'error',
                        error: updateError.message
                    });
                }
                else {
                    v1_1.logger.info(`✅ Successfully expired appointment ${appointment.id}`);
                    expiredCount++;
                    details.push({
                        id: appointment.id,
                        status: 'expired'
                    });
                    // Optional: Create a notification for the user about expiration
                    try {
                        await createExpirationNotification(appointment);
                    }
                    catch (notifError) {
                        v1_1.logger.warn(`⚠️ Failed to create expiration notification for appointment ${appointment.id}:`, notifError);
                        // Don't fail the whole operation for notification errors
                    }
                }
            }
            catch (error) {
                v1_1.logger.error(`❌ Error processing appointment ${appointment.id}:`, error);
                errorCount++;
                details.push({
                    id: appointment.id,
                    status: 'error',
                    error: error.message
                });
            }
        }
        // Log summary
        v1_1.logger.info(`📊 Expiration summary:`);
        v1_1.logger.info(`   ✅ Expired: ${expiredCount}`);
        v1_1.logger.info(`   ❌ Errors: ${errorCount}`);
        v1_1.logger.info(`   📋 Total processed: ${pendingAppointments.length}`);
        return {
            expiredCount,
            errorCount,
            details
        };
    }
    catch (error) {
        v1_1.logger.error('❌ Critical error in expireOverdueAppointments:', error);
        throw error;
    }
}
exports.expireOverdueAppointments = expireOverdueAppointments;
/**
 * Create a notification for the user about appointment expiration
 */
async function createExpirationNotification(appointment) {
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
            v1_1.logger.warn(`⚠️ Failed to create expiration notification for user ${appointment.user_id}:`, error);
        }
        else {
            v1_1.logger.info(`📬 Created expiration notification for user ${appointment.user_id}`);
        }
    }
    catch (error) {
        v1_1.logger.warn(`⚠️ Error creating expiration notification:`, error);
    }
}
/**
 * Utility function to manually trigger expiration for testing
 * This can be called from admin panel or debugging
 */
async function triggerAppointmentExpiration() {
    v1_1.logger.info('🔧 Manual trigger: Appointment expiration starting...');
    try {
        // Write to Firebase to trigger the function
        const triggerRef = realtimeDb.ref('/manual_expire_appointments');
        await triggerRef.set({
            triggeredAt: new Date().toISOString(),
            triggeredBy: 'manual_call'
        });
        v1_1.logger.info('✅ Manual trigger: Appointment expiration initiated');
    }
    catch (error) {
        v1_1.logger.error('❌ Manual trigger: Error triggering appointment expiration:', error);
        throw error;
    }
}
exports.triggerAppointmentExpiration = triggerAppointmentExpiration;
//# sourceMappingURL=appointmentExpiration.js.map