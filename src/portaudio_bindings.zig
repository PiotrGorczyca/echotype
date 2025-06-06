const std = @import("std");

// PortAudio C library bindings
pub const c = @cImport({
    @cInclude("portaudio.h");
});

// Type aliases for cleaner code
pub const PaError = c.PaError;
pub const PaStream = c.PaStream;
pub const PaStreamParameters = c.PaStreamParameters;
pub const PaStreamInfo = c.PaStreamInfo;
pub const PaDeviceIndex = c.PaDeviceIndex;
pub const PaDeviceInfo = c.PaDeviceInfo;
pub const PaSampleFormat = c.PaSampleFormat;
pub const PaStreamCallback = c.PaStreamCallback;
pub const PaStreamFlags = c.PaStreamFlags;

// Error codes
pub const paNoError = c.paNoError;
pub const paInputOverflowed = c.paInputOverflowed;
pub const paOutputUnderflowed = c.paOutputUnderflowed;

// Sample formats
pub const paFloat32 = c.paFloat32;
pub const paInt32 = c.paInt32;
pub const paInt24 = c.paInt24;
pub const paInt16 = c.paInt16;
pub const paInt8 = c.paInt8;
pub const paUInt8 = c.paUInt8;

// Special device indices
pub const paNoDevice = c.paNoDevice;
pub const paUseHostApiSpecificDeviceSpecification = c.paUseHostApiSpecificDeviceSpecification;

// Stream flags
pub const paNoFlag = c.paNoFlag;
pub const paClipOff = c.paClipOff;
pub const paDitherOff = c.paDitherOff;
pub const paNeverDropInput = c.paNeverDropInput;
pub const paPrimeOutputBuffersUsingStreamCallback = c.paPrimeOutputBuffersUsingStreamCallback;

// Buffer size constants
pub const paFramesPerBufferUnspecified = c.paFramesPerBufferUnspecified;

// Callback results
pub const paContinue = c.paContinue;
pub const paComplete = c.paComplete;
pub const paAbort = c.paAbort;

// Wrapper functions for PortAudio API
pub fn initialize() PaError {
    return c.Pa_Initialize();
}

pub fn terminate() PaError {
    return c.Pa_Terminate();
}

pub fn getVersion() c_int {
    return c.Pa_GetVersion();
}

pub fn getVersionText() [*:0]const u8 {
    return c.Pa_GetVersionText();
}

pub fn getErrorText(errorCode: PaError) [*:0]const u8 {
    return c.Pa_GetErrorText(errorCode);
}

pub fn getDeviceCount() PaDeviceIndex {
    return c.Pa_GetDeviceCount();
}

pub fn getDefaultInputDevice() PaDeviceIndex {
    return c.Pa_GetDefaultInputDevice();
}

pub fn getDefaultOutputDevice() PaDeviceIndex {
    return c.Pa_GetDefaultOutputDevice();
}

pub fn getDeviceInfo(device: PaDeviceIndex) ?*const PaDeviceInfo {
    return c.Pa_GetDeviceInfo(device);
}

pub fn isFormatSupported(
    inputParameters: ?*const PaStreamParameters,
    outputParameters: ?*const PaStreamParameters,
    sampleRate: f64,
) PaError {
    return c.Pa_IsFormatSupported(inputParameters, outputParameters, sampleRate);
}

pub fn openStream(
    stream: *?*PaStream,
    inputParameters: ?*const PaStreamParameters,
    outputParameters: ?*const PaStreamParameters,
    sampleRate: f64,
    framesPerBuffer: c_ulong,
    streamFlags: PaStreamFlags,
    streamCallback: ?*const fn (?*const anyopaque, ?*anyopaque, c_ulong, [*c]const c.PaStreamCallbackTimeInfo, c.PaStreamCallbackFlags, ?*anyopaque) callconv(.C) c_int,
    userData: ?*anyopaque,
) PaError {
    return c.Pa_OpenStream(
        stream,
        inputParameters,
        outputParameters,
        sampleRate,
        framesPerBuffer,
        streamFlags,
        streamCallback,
        userData,
    );
}

pub fn openDefaultStream(
    stream: *?*PaStream,
    numInputChannels: c_int,
    numOutputChannels: c_int,
    sampleFormat: PaSampleFormat,
    sampleRate: f64,
    framesPerBuffer: c_ulong,
    streamCallback: ?PaStreamCallback,
    userData: ?*anyopaque,
) PaError {
    return c.Pa_OpenDefaultStream(
        stream,
        numInputChannels,
        numOutputChannels,
        sampleFormat,
        sampleRate,
        framesPerBuffer,
        streamCallback,
        userData,
    );
}

pub fn closeStream(stream: ?*PaStream) PaError {
    return c.Pa_CloseStream(stream);
}

pub fn startStream(stream: ?*PaStream) PaError {
    return c.Pa_StartStream(stream);
}

pub fn stopStream(stream: ?*PaStream) PaError {
    return c.Pa_StopStream(stream);
}

pub fn abortStream(stream: ?*PaStream) PaError {
    return c.Pa_AbortStream(stream);
}

pub fn isStreamStopped(stream: ?*PaStream) PaError {
    return c.Pa_IsStreamStopped(stream);
}

pub fn isStreamActive(stream: ?*PaStream) PaError {
    return c.Pa_IsStreamActive(stream);
}

pub fn getStreamInfo(stream: ?*PaStream) ?*const PaStreamInfo {
    return c.Pa_GetStreamInfo(stream);
}

pub fn getStreamTime(stream: ?*PaStream) f64 {
    return c.Pa_GetStreamTime(stream);
}

pub fn getStreamCpuLoad(stream: ?*PaStream) f64 {
    return c.Pa_GetStreamCpuLoad(stream);
}

pub fn readStream(stream: ?*PaStream, buffer: *anyopaque, frames: c_ulong) PaError {
    return c.Pa_ReadStream(stream, buffer, frames);
}

pub fn writeStream(stream: ?*PaStream, buffer: *const anyopaque, frames: c_ulong) PaError {
    return c.Pa_WriteStream(stream, buffer, frames);
}

pub fn getStreamReadAvailable(stream: ?*PaStream) c_long {
    return c.Pa_GetStreamReadAvailable(stream);
}

pub fn getStreamWriteAvailable(stream: ?*PaStream) c_long {
    return c.Pa_GetStreamWriteAvailable(stream);
}

pub fn sleep(msec: c_long) void {
    c.Pa_Sleep(msec);
}
