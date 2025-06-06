const std = @import("std");

pub const WhisperClient = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    http_client: std.http.Client,

    const Self = @This();
    const WHISPER_API_URL = "https://api.openai.com/v1/audio/transcriptions";

    pub fn init(allocator: std.mem.Allocator, api_key: []const u8) Self {
        return Self{
            .allocator = allocator,
            .api_key = api_key,
            .http_client = std.http.Client{ .allocator = allocator },
        };
    }

    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
    }

    pub fn transcribe(self: *Self, audio_file_path: []const u8) ![]const u8 {
        std.debug.print("Sending audio file to Whisper API: {s}\n", .{audio_file_path});

        // Check if file exists
        const file = std.fs.cwd().openFile(audio_file_path, .{}) catch |err| {
            std.debug.print("Error opening audio file: {}\n", .{err});
            return error.FileNotFound;
        };
        defer file.close();

        // Get file size
        const file_size = try file.getEndPos();
        std.debug.print("Audio file size: {} bytes\n", .{file_size});
        if (file_size == 0) {
            return error.EmptyFile;
        }

        // Read file content
        const file_content = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(file_content);
        const bytes_read = try file.readAll(file_content);
        std.debug.print("Read {} bytes from audio file\n", .{bytes_read});

        // Create multipart form data
        const boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW";
        const form_data = try self.createMultipartFormData(file_content, boundary);
        defer self.allocator.free(form_data);
        std.debug.print("Form data size: {} bytes\n", .{form_data.len});

        // Prepare headers
        const auth_header = try std.fmt.allocPrint(self.allocator, "Bearer {s}", .{self.api_key});
        defer self.allocator.free(auth_header);

        const content_type = try std.fmt.allocPrint(self.allocator, "multipart/form-data; boundary={s}", .{boundary});
        defer self.allocator.free(content_type);

        // Make HTTP request
        const uri = try std.Uri.parse(WHISPER_API_URL);

        const server_header_buffer = try self.allocator.alloc(u8, 16384);
        defer self.allocator.free(server_header_buffer);

        var req = try self.http_client.open(.POST, uri, .{
            .server_header_buffer = server_header_buffer,
        });
        defer req.deinit();

        req.headers.authorization = .{ .override = auth_header };
        req.headers.content_type = .{ .override = content_type };

        req.transfer_encoding = .{ .content_length = form_data.len };

        try req.send();
        const writer = req.writer();
        try writer.writeAll(form_data);
        try req.finish();
        try req.wait();

        // Check response status
        std.debug.print("Response status: {}\n", .{req.response.status});
        if (req.response.status != .ok) {
            std.debug.print("API request failed with status: {}\n", .{req.response.status});

            // Try to read error response for debugging
            const error_body = req.reader().readAllAlloc(self.allocator, 1024) catch "Unable to read error response";
            defer self.allocator.free(error_body);
            std.debug.print("Error response: {s}\n", .{error_body});

            return error.ApiRequestFailed;
        }

        // Read response
        const response_body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024); // 1MB max
        defer self.allocator.free(response_body);
        std.debug.print("Response body length: {} bytes\n", .{response_body.len});
        std.debug.print("Response preview: {s}\n", .{response_body[0..@min(200, response_body.len)]});

        // Parse JSON response
        const transcription = try self.parseTranscriptionResponse(response_body);
        return transcription;
    }

    fn createMultipartFormData(self: *Self, file_content: []const u8, boundary: []const u8) ![]u8 {
        var form_parts = std.ArrayList(u8).init(self.allocator);
        defer form_parts.deinit();

        // Add model field
        try form_parts.appendSlice("--");
        try form_parts.appendSlice(boundary);
        try form_parts.appendSlice("\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\n");
        try form_parts.appendSlice("whisper-1");
        try form_parts.appendSlice("\r\n");

        // Add file field
        try form_parts.appendSlice("--");
        try form_parts.appendSlice(boundary);
        try form_parts.appendSlice("\r\nContent-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n");
        try form_parts.appendSlice("Content-Type: audio/wav\r\n\r\n");
        try form_parts.appendSlice(file_content);
        try form_parts.appendSlice("\r\n");

        // Language field removed to allow auto-detection of original language

        // Add response format
        try form_parts.appendSlice("--");
        try form_parts.appendSlice(boundary);
        try form_parts.appendSlice("\r\nContent-Disposition: form-data; name=\"response_format\"\r\n\r\n");
        try form_parts.appendSlice("json");
        try form_parts.appendSlice("\r\n");

        // Close boundary
        try form_parts.appendSlice("--");
        try form_parts.appendSlice(boundary);
        try form_parts.appendSlice("--\r\n");

        return try form_parts.toOwnedSlice();
    }

    fn parseTranscriptionResponse(self: *Self, json_response: []const u8) ![]const u8 {
        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, json_response, .{}) catch |err| {
            std.debug.print("Failed to parse JSON response: {}\n", .{err});
            std.debug.print("Response was: {s}\n", .{json_response});
            return error.JsonParseError;
        };
        defer parsed.deinit();

        const root = parsed.value.object;

        // Check for error in response
        if (root.get("error")) |error_obj| {
            const error_message = error_obj.object.get("message").?.string;
            std.debug.print("API returned error: {s}\n", .{error_message});
            return error.ApiError;
        }

        // Extract transcription text
        const text = root.get("text") orelse {
            std.debug.print("No 'text' field in response\n", .{});
            return error.MissingTextField;
        };

        // Duplicate the string before the JSON parser is deallocated
        const transcription_text = try self.allocator.dupe(u8, text.string);
        std.debug.print("Transcription extracted: {s}\n", .{transcription_text});
        return transcription_text;
    }
};
