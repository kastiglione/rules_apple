# Copyright 2018 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Experimental implementation of iOS rules."""

load(
    "@build_bazel_rules_apple//apple/bundling:platform_support.bzl",
    "platform_support",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:partials.bzl",
    "partials",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental:processor.bzl",
    "processor",
)
load(
    "@build_bazel_rules_apple//apple/bundling/experimental/partials:embedded_bundles.bzl",
    "collect_embedded_bundle_provider",
)
load(
    "@build_bazel_rules_apple//apple:providers.bzl",
    "AppleBundleInfo",
    "IosApplicationBundleInfo",
    "IosExtensionBundleInfo",
    "IosFrameworkBundleInfo",
)

def ios_application_impl(ctx):
    """Experimental implementation of ios_application."""

    # TODO(kaipi): Handle other things related to iOS apps, like frameworks,
    # extensions and SwiftSupport.
    top_level_attrs = [
        "app_icons",
        "launch_images",
        "launch_storyboard",
        "settings_bundle",
        "strings",
    ]

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary
    embeddable_targets = ctx.attr.frameworks + ctx.attr.extensions
    if ctx.attr.watch_application:
        embeddable_targets.append(ctx.attr.watch_application)

    processor_partials = [
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.bitcode_symbols_partial(
            binary_artifact = binary_artifact,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = ctx.attr.frameworks + ctx.attr.extensions,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.embedded_bundles_partial(targets = embeddable_targets),
        partials.resources_partial(
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = top_level_attrs,
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks + ctx.attr.extensions,
            package_dylibs = True,
        ),
    ]

    if platform_support.is_device_build(ctx):
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile)
        )

    processor_result = processor.process(ctx, processor_partials)

    # TODO(kaipi): Add support for `bazel run` for ios_application.
    executable = ctx.actions.declare_file(ctx.label.name)
    ctx.actions.write(
        executable,
        "#!/bin/bash\necho Unimplemented",
        is_executable = True,
    )

    return [
        # TODO(kaipi): Fill in the fields of AppleBundleInfo.
        AppleBundleInfo(),
        DefaultInfo(
            executable = executable,
            files = processor_result.output_files,
        ),
        IosApplicationBundleInfo(),
    ] + processor_result.providers

def ios_framework_impl(ctx):
    """Experimental implementation of ios_framework."""
    # TODO(kaipi): Add support for packaging headers.

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleDylibBinary].binary

    processor_partials = [
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.bitcode_symbols_partial(
            binary_artifact = binary_artifact,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        # TODO(kaipi): Check if clang_rt dylibs are needed in Frameworks, or if
        # the can be skipped.
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.framework_provider_partial(),
        partials.resources_partial(
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
        ),
    ]

    processor_result = processor.process(ctx, processor_partials)

    # This can't be made into a partial as it needs the output archive reference.
    # TODO(kaipi): Remove direct reference to ctx.outputs.archive.
    embedded_bundles_provider = collect_embedded_bundle_provider(
        frameworks = [ctx.outputs.archive],
        targets = ctx.attr.frameworks,
    )

    return [
        # TODO(kaipi): Fill in the fields of AppleBundleInfo.
        AppleBundleInfo(),
        DefaultInfo(files = processor_result.output_files),
        embedded_bundles_provider,
        IosFrameworkBundleInfo(),
    ] + processor_result.providers

def ios_extension_impl(ctx):
    """Experimental implementation of ios_extension."""
    top_level_attrs = [
        "app_icons",
        "strings",
    ]

    # TODO(kaipi): Replace the debug_outputs_provider with the provider returned from the linking
    # action, when available.
    # TODO(kaipi): Extract this into a common location to be reused and refactored later when we
    # add linking support directly into the rule.
    binary_target = ctx.attr.deps[0]
    binary_artifact = binary_target[apple_common.AppleExecutableBinary].binary

    processor_partials = [
        partials.binary_partial(binary_artifact = binary_artifact),
        partials.bitcode_symbols_partial(
            binary_artifact = binary_artifact,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.clang_rt_dylibs_partial(binary_artifact = binary_artifact),
        partials.debug_symbols_partial(
            debug_dependencies = ctx.attr.frameworks,
            debug_outputs_provider = binary_target[apple_common.AppleDebugOutputs],
        ),
        partials.resources_partial(
            plist_attrs = ["infoplists"],
            targets_to_avoid = ctx.attr.frameworks,
            top_level_attrs = top_level_attrs,
        ),
        partials.swift_dylibs_partial(
            binary_artifact = binary_artifact,
            dependency_targets = ctx.attr.frameworks,
        ),
    ]

    if platform_support.is_device_build(ctx):
        processor_partials.append(
            partials.provisioning_profile_partial(profile_artifact = ctx.file.provisioning_profile)
        )

    processor_result = processor.process(ctx, processor_partials)

    # This can't be made into a partial as it needs the output archive
    # reference.
    # TODO(kaipi): Remove direct reference to ctx.outputs.archive.
    embedded_bundles_provider = collect_embedded_bundle_provider(
        plugins = [ctx.outputs.archive],
        targets = ctx.attr.frameworks,
    )

    return [
        # TODO(kaipi): Fill in the fields of AppleBundleInfo.
        AppleBundleInfo(),
        DefaultInfo(
            files = processor_result.output_files,
        ),
        embedded_bundles_provider,
        IosExtensionBundleInfo(),
    ] + processor_result.providers
