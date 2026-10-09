var IntegrationMessageService = Class.create();
IntegrationMessageService.prototype = {
    initialize: function() {
        this.TRANSACTION_TABLE = 'x_vaea2_supplier_0_transaction_queue';
        this.DIRECTION_INBOUND = 'inbound';
        this.DIRECTION_OUTBOUND = 'outbound';
        this.PROCESSING_MODE_SYNCHRONOUS = 'synchronous';
        this.PROCESSING_MODE_ASYNCHRONOUS = 'asynchronous';
        this.STATUS_READY = 'ready';
        this.STATUS_PROCESSING = 'processing';
        this.STATUS_PROCESSED = 'processed';
        this.STATUS_FAILED = 'failed';
        this.TYPE_INCIDENT = 'incident';
        this.ACTION_CREATE = 'create';
        this.ACTION_ACCEPT = 'accept';
        this.ACTION_UPDATE = 'update';
        this.ACTION_AWAITING_INFO = 'awaiting_info';
        this.ACTION_AWAITING_CHANGE = 'awaiting_change';
        this.ACTION_RESOLVE = 'resolve';
        this.ACTION_CANCEL = 'cancel';
        this.FIELD_ID = 'id';
        this.FIELD_SYS_ID = 'sys_id';
        this.FIELD_NUMBER = 'number';
        this.FIELD_SHORT_DESCRIPTION = 'short_description';
        this.FIELD_DESCRIPTION = 'description';
        this.FIELD_PRIORITY = 'priority';
        this.FIELD_SERVICE_OFFERING = 'service_offering';
        this.FIELD_EXTERNAL_COMMENT = 'external_comment';
        this.FIELD_INTERNAL_COMMENT = 'internal_comment';
        this.FIELD_WORK_NOTES = 'work_notes';
        this.FIELD_COMMENTS = 'comments';
        this.FIELD_CLOSE_NOTES = 'close_notes';
        this.FIELD_STATE = 'state';
        this.FIELD_REMOTE_ID = 'remote_id';
        this.FIELD_REMOTE_NUMBER = 'remote_number';
    },

    /**
     * Processes an inbound integration request. Logs the transaction, validates the request payload, and routes the message to the appropriate handler.
     * @param {RESTAPIRequest} request Inbound REST request
     * @param {RESTAPIResponse} response Outbound REST response
     * @returns {void}
     */
    receive: function(request, response) {
        this.request = request;
        this.response = response;
        this.requestBody = request.body.dataString;

        // Add request to transaction queue
        this._createTransactionQueueRecord(this.DIRECTION_INBOUND, this.PROCESSING_MODE_SYNCHRONOUS, this.request.url, this.requestBody, '', '', '');

        // Always use synchronous processing for now. Support for asynchronous processing may be added later
        this._updateTransactionQueueRecord({
            "status": this.STATUS_PROCESSING
        });

        // Validate request body is not empty
        if (!this.requestBody) {
            this._updateTransactionQueueRecord({
                "status": this.STATUS_FAILED,
                "http_status": 400
            });
            this.response.setError(new sn_ws_err.BadRequestError(
                'Invalid request body'
            ));
            return;
        }

        // Parse request body as JSON
        try {
            this.requestBody = JSON.parse(this.requestBody);
        } catch (ex) {
            this._updateTransactionQueueRecord({
                "status": this.STATUS_FAILED,
                "http_status": 400
            });
            this.response.setError(new sn_ws_err.BadRequestError(
                'Invalid request body: The payload could not be parsed as valid JSON'
            ));
            return;
        }

        // Validate request body contains mandatory fields
        var mandatoryFields = ['type', 'action', 'data'];
        if (!this._validateMandatoryFields(this.requestBody, mandatoryFields)) {
            return;
        }

        // Route message to the appropriate handler
        if (this.requestBody.type == this.TYPE_INCIDENT) {
            this._receiveIncident(this.requestBody.action, this.requestBody.data);
        } else {
            this._updateTransactionQueueRecord({
                "status": this.STATUS_FAILED,
                "http_status": 400
            });
            this.response.setError(new sn_ws_err.BadRequestError(
                'Invalid request body: Type not supported'
            ));
            return;
        }
    },

    /**
     * Sends an outbound integration request. Routes the message to the appropriate handler.
     * @param {GlideRecord} grTask GlideRecord representing the task to integrate on
     * @returns {void}
     */
    send: function(grTask) {
        // Route message to the appropriate handler
        if (grTask.sys_class_name == 'incident_task') {
            this._sendIncident(grTask);
        }
    },

    /**
     * Processes an outbound integration request. Routes the message to the appropriate handler.
     * @param {GlideRecord} transactionQueueGr GlideRecord representing the transaction queue record to process
     * @returns {void}
     */
    processSend(transactionQueueGr) {
        // Route message to the appropriate handler
        if (transactionQueueGr.table == 'incident_task') {
            this._processSendIncident(transactionQueueGr);
        }
    },

    _createTransactionQueueRecord(direction, processingMode, requestPath, requestPayload, connection, table, documentId) {
        this.transactionQueueGr = new GlideRecord(this.TRANSACTION_TABLE);
        this.transactionQueueGr.initialize();
        this.transactionQueueGr.direction = direction;
        this.transactionQueueGr.processing_mode = processingMode;
        this.transactionQueueGr.request_path = requestPath;
        this.transactionQueueGr.request_payload = requestPayload;
        if (connection)
            this.transactionQueueGr.connection = connection;
        if (table)
            this.transactionQueueGr.table = table;
        if (documentId)
            this.transactionQueueGr.document_id = documentId;
        this.transactionQueueGr.status = this.STATUS_READY;
        this.transactionQueueGr.insert();
    },

    _updateTransactionQueueRecord(data) {
        if (!data) {
            return false;
        }
        for (var prop in data) {
            this.transactionQueueGr[prop] = data[prop];
        }
        this.transactionQueueGr.update();
    },

    _validateMandatoryFields(obj, mandatoryFields) {
        var issues = [];
        for (var i in mandatoryFields) {
            var field = mandatoryFields[i];
            if (!obj.hasOwnProperty(field) || obj[field] === null || obj[field] === undefined || typeof obj[field] === 'string' && obj[field].trim() === '')
                issues.push(field);
        }
        if (issues.length > 0) {
            this._updateTransactionQueueRecord({
                "status": this.STATUS_FAILED,
                "http_status": 400
            });
            this.response.setError(new sn_ws_err.BadRequestError(
                'Invalid request body: Missing mandatory field' + (issues.length > 1 ? 's' : '') + ' ' + issues.join(', ')
            ));
            return false;
        }
        return true;
    },

    _receiveIncident(action, data) {
        var supportedActions = [this.ACTION_ACCEPT, this.ACTION_UPDATE, this.ACTION_AWAITING_INFO, this.ACTION_AWAITING_CHANGE, this.ACTION_RESOLVE, this.ACTION_CANCEL];
        var supportedFields = [this.FIELD_SHORT_DESCRIPTION, this.FIELD_DESCRIPTION, this.FIELD_PRIORITY, this.FIELD_SERVICE_OFFERING, this.FIELD_INTERNAL_COMMENT];

        if (supportedActions.includes(action)) {
            var mandatoryFields = [this.FIELD_ID];
            if (!this._validateMandatoryFields(data, mandatoryFields))
                return;
            // Get user assignment groups of type supplier_hub
            var groups = [];
            var grMemberGr = new GlideRecord('sys_user_grmember');
            grMemberGr.addQuery('group.type', 'CONTAINS', '4a32ffe2896ac310b214e1134ad2532b'); // supplier_hub
            grMemberGr.addQuery('group.active', 'true');
            grMemberGr.addQuery('user', gs.getUserID());
            grMemberGr.query();
            while (grMemberGr.next()) {
                groups.push(grMemberGr.group);
            }
            // If user is not member of any supplier_hub groups then abort
            if (groups.length == 0) {
                this._updateTransactionQueueRecord({
                    "status": this.STATUS_FAILED,
                    "http_status": 401
                });
                var error = new sn_ws_err.ServiceError();
                error.setStatus(401);
                error.setMessage('User is not member of any integration groups');
                this.response.setError(error);
                return false;
            }
            // TODO: GlideRecordSecure instead of GlideRecord?
            // If using GlideRecordSecure then user must have a proper role to read the record
            // and it would imply creating ACLs to limit access. If using GlideRecord we can
            // handle the security in this script instead
            var incidentTaskGr = new GlideRecord('incident_task');
            incidentTaskGr.addQuery('sys_id', data[this.FIELD_ID]);
            incidentTaskGr.addQuery('assignment_group', 'IN', groups);
            incidentTaskGr.query();
            if (!incidentTaskGr.next()) {
                this._updateTransactionQueueRecord({
                    "status": this.STATUS_FAILED,
                    "http_status": 404
                });
                this.response.setError(new sn_ws_err.NotFoundError(
                    'Incident not found'
                ));
                return false;
            }
            // Get related incident record
            var incidentGr = incidentTaskGr.incident.getRefRecord();
            if (action == this.ACTION_ACCEPT) {
                incidentTaskGr.state = 2; // Work in progress
            } else if (action == this.ACTION_UPDATE) {
                // No state change, fields are updated below
            } else if (action == this.ACTION_AWAITING_INFO) {
                mandatoryFields = [this.FIELD_EXTERNAL_COMMENT];
                if (!this._validateMandatoryFields(data, mandatoryFields))
                    return;
                incidentTaskGr.state = -5; // Pending
                incidentGr.state = 3; // On Hold
                incidentGr.hold_reason = 1; // Awaiting Caller
                // TODO: Check mandatory work notes requirement when changing state
                incidentGr.work_notes = 'Changing state to Awaiting Caller';
            } else if (action == this.ACTION_AWAITING_CHANGE) {
                incidentTaskGr.state = -5; // Pending
                incidentGr.state = 3; // On Hold
                incidentGr.hold_reason = 5; // Awaiting Change
                // TODO: Check mandatory work notes requirement when changing state
                incidentGr.work_notes = 'Changing state to Awaiting Change';
            } else if (action == this.ACTION_RESOLVE) {
                mandatoryFields = [this.FIELD_CLOSE_NOTES];
                if (!this._validateMandatoryFields(data, mandatoryFields))
                    return;
                incidentTaskGr.close_notes = data[this.FIELD_CLOSE_NOTES];
                incidentTaskGr.state = 3; // Closed Complete
            } else if (action == this.ACTION_CANCEL) {
                incidentGr.state = 2; // Work in progress
                incidentGr.assignment_group = '1df230e295710b10c32b297ccd28c893'; // Helpdesk
                incidentTaskGr.state = 5; // Closed Incomplete
            }
            // Update fields
            this._updateRecordFields(incidentTaskGr, supportedFields, data);
            // If data contains external comment then add it to parent incident record
            if (data[this.FIELD_EXTERNAL_COMMENT]) {
                incidentGr.comments = data[this.FIELD_EXTERNAL_COMMENT];
            }
            // TODO: Only update incidident if it has been modified
            incidentGr.update();
            incidentTaskGr.update();
            this._updateTransactionQueueRecord({
                "status": this.STATUS_PROCESSED,
                "http_status": 200
            });
            this.response.setStatus(200);
        } else {
            this._updateTransactionQueueRecord({
                "status": this.STATUS_FAILED,
                "http_status": 400
            });
            this.response.setError(new sn_ws_err.BadRequestError(
                'Action not supported'
            ));
            return false;
        }
    },

    _sendIncident(incidentTaskGr) {
        var requestBody;
        var connectionGr = new GlideRecord('x_vaea2_supplier_0_connection');
        connectionGr.addQuery('groups', 'CONTAINS', incidentTaskGr.assignment_group);
        connectionGr.query();
        if (!connectionGr.next()) {
            // Connection is not defined for this group
            return;
        }
        // Handles incident task on insert and re-assignment to Supplier on update
        if (
            (incidentTaskGr.operation() == 'insert') ||
            (incidentTaskGr.operation() == 'update' && !incidentTaskGr.correlation_id)
        ) {
            // Build request body
            requestBody = {
                type: this.TYPE_INCIDENT,
                action: this.ACTION_CREATE,
                data: {
                    [this.FIELD_ID]: incidentTaskGr.sys_id + '',
                    [this.FIELD_NUMBER]: incidentTaskGr.number + '',
                    [this.FIELD_SHORT_DESCRIPTION]: incidentTaskGr.short_description + '',
                    [this.FIELD_DESCRIPTION]: incidentTaskGr.description + '',
                    [this.FIELD_PRIORITY]: incidentTaskGr.priority + '',
                    [this.FIELD_SERVICE_OFFERING]: incidentTaskGr.incident.service_offering + ''
                    // External comment is not used on incident task
                }
            };
            // Add work notes if any
            var workNotes = incidentTaskGr.work_notes.getJournalEntry(1);
            if (workNotes) {
                requestBody.data[this.FIELD_INTERNAL_COMMENT] = this._parseJournalEntry(workNotes).comment + '';
            }
        } else if (incidentTaskGr.operation() == 'update') {
            var supportedFields = [this.FIELD_SHORT_DESCRIPTION, this.FIELD_DESCRIPTION, this.FIELD_PRIORITY, this.FIELD_SERVICE_OFFERING, this.FIELD_WORK_NOTES, this.FIELD_STATE];
            // Build request body
            requestBody = {
                type: this.TYPE_INCIDENT,
                action: this.ACTION_UPDATE,
                data: {
                    [this.FIELD_ID]: incidentTaskGr.sys_id + ''
                }
            };
            var changedFields = [];
            var elements = incidentTaskGr.getElements();
            for (var i = 0; i < elements.length; i++) {
                var element = elements[i];
                if (element.changes() && supportedFields.includes(element.getName())) {
                    changedFields.push(element.getName());
                    if (element.getName() == this.FIELD_WORK_NOTES) {
                        requestBody.data[this.FIELD_INTERNAL_COMMENT] = this._parseJournalEntry(incidentTaskGr[this.FIELD_WORK_NOTES].getJournalEntry(1)).comment + '';
                    } else {
                        requestBody.data[element.getName()] = incidentTaskGr[element.getName()] + '';
                    }
                }
            }
            if (!changedFields.length) {
                return;
            }
            if (changedFields.includes('state')) {
                if (incidentTaskGr.state == 3) {
                    requestBody.action = this.ACTION_RESOLVE;
                } else if (incidentTaskGr.state == 4) {
                    requestBody.action = this.ACTION_CANCEL;
                }
            }
        }
        this._createTransactionQueueRecord(this.DIRECTION_OUTBOUND, this.PROCESSING_MODE_ASYNCHRONOUS, connectionGr.outbound_rest_endpoint, JSON.stringify(requestBody), connectionGr.getUniqueValue(), incidentTaskGr.getTableName(), incidentTaskGr.getUniqueValue());
    },

    _processSendIncident(transactionQueueGr) {
        this.transactionQueueGr = transactionQueueGr;
        this._updateTransactionQueueRecord({
            "status": this.STATUS_PROCESSING
        });
        var incidentTaskGr = new GlideRecord(transactionQueueGr.table);
        if (!incidentTaskGr.get(transactionQueueGr.document_id)) {
            this._updateTransactionQueueRecord({
                "status": this.STATUS_FAILED
            });
        }
        try {
            var request = new sn_ws.RESTMessageV2();
            request.setHttpMethod('POST');
            request.setEndpoint(transactionQueueGr.connection.outbound_rest_endpoint);
            request.setAuthenticationProfile('oauth2', transactionQueueGr.connection.outbound_oauth_profile);
            request.setRequestorProfile();
            request.setRequestHeader('Content-type', 'application/json');
            request.setRequestBody(transactionQueueGr.request_payload);
            var response = request.execute();
            var responseBody = response.haveError() ? response.getErrorMessage() : response.getBody();
            var status = response.getStatusCode();
            this._updateTransactionQueueRecord({
                "http_status": status,
                "response_payload": responseBody
            });
            // TODO: Expect 201 on action=insert, expect 200 on all other actions
            // Else failed

            var requestBodyObj = JSON.parse(transactionQueueGr.request_payload);
            var action = requestBodyObj.action;

            var success =
                (action === 'create' && status === 201) ||
                (action !== 'create' && status === 200);

            if (success) {

                if (status === 201) {
                    var responseBodyObj = JSON.parse(responseBody);

                    if (responseBodyObj.result.remote_id)
                        incidentTaskGr.correlation_id = responseBodyObj.result.remote_id;

                    if (responseBodyObj.result.remote_number)
                        incidentTaskGr.correlation_display = responseBodyObj.result.remote_number;
                }

                this._updateTransactionQueueRecord({
                    status: this.STATUS_PROCESSED
                });

            } else {

                this._updateTransactionQueueRecord({
                    status: this.STATUS_FAILED
                });
            }
        } catch (ex) {
            incidentTaskGr.work_notes = 'Incident task integration failed: ' + ex.getMessage();
            this._updateTransactionQueueRecord({
                "status": this.STATUS_FAILED
            });
        } finally {
            incidentTaskGr.update();
        }
    },

    _updateRecordFields(gr, fields, data) {
        for (var i in fields) {
            field = fields[i];
            value = data[field];
            if (value) {
                // Replace field name
                if (field == this.FIELD_INTERNAL_COMMENT)
                    field = 'work_notes';
                gr[field] = typeof value === 'string' ? value.trim() : value;
            }
        }
    },

    _parseJournalEntry(rawEntry) {
        var parsedEntry = {};
        // Step 1 Separate the header line from the actual comment body
        var newlineIndex = rawEntry.indexOf('\n');
        if (newlineIndex !== -1) {
            var headerLine = rawEntry.substring(0, newlineIndex);
            parsedEntry.comment = rawEntry.substring(newlineIndex + 1).trim();

            // Step 2 Use a flexible regex to split the header components
            // Group 1 (.*?) matches any timestamp format up to the " - "
            // Group 2 (.*?) matches the author name up to the opening parenthesis " ("
            // Group 3 \((.*?)\) matches the field type inside the parentheses
            var headerRegex = /^(.*?)\s-\s(.*?)\s\((.*?)\)$/;
            var match = headerLine.match(headerRegex);
            if (match) {
                parsedEntry.timestamp = match[1];
                parsedEntry.author = match[2];
                parsedEntry.type = match[3];
            }
        }
        return parsedEntry;
    },

    type: 'IntegrationMessageService'
};
