"""Rule for creating AppImages."""

load("@rules_appimage//appimage/private:mkapprun.bzl", "make_apprun")
load("@rules_appimage//appimage/private:runfiles.bzl", "collect_runfiles_info")

def _appimage_impl(ctx):
    """Implementation of the appimage rule."""
    toolchain = ctx.toolchains["//appimage:appimage_toolchain_type"]

    tools = depset(
        direct = [ctx.executable._tool],
        transitive = [ctx.attr._tool[DefaultInfo].default_runfiles.files],
    )
    runfile_info = collect_runfiles_info(ctx)
    manifest_file = ctx.actions.declare_file(ctx.attr.name + "-manifest.json")
    ctx.actions.write(manifest_file, json.encode_indent(runfile_info.manifest))
    apprun = make_apprun(ctx)
    inputs = depset(direct = [ctx.file.icon, manifest_file, apprun, toolchain.appimage_runtime] + runfile_info.files)

    # TODO: Use Skylib's shell.quote?
    args = [
        "--manifest={}".format(manifest_file.path),
        "--apprun={}".format(apprun.path),
        "--icon={}".format(ctx.file.icon.path),
        "--runtime={}".format(toolchain.appimage_runtime.path),
    ]
    args.extend(["--mksquashfs_arg=" + arg for arg in ctx.attr.build_args])
    args.append(ctx.outputs.executable.path)

    # Take the `binary` env and add the appimage target's env on top of it
    env = {}
    if RunEnvironmentInfo in ctx.attr.binary:
        env.update(ctx.attr.binary[RunEnvironmentInfo].environment)
    env.update(ctx.attr.env)

    # Run our tool to create the AppImage
    ctx.actions.run(
        mnemonic = "AppImage",
        inputs = inputs,
        env = ctx.attr.build_env,
        executable = ctx.executable._tool,
        arguments = args,
        outputs = [ctx.outputs.executable],
        tools = tools,
    )

    return [
        DefaultInfo(
            executable = ctx.outputs.executable,
            files = depset([ctx.outputs.executable]),
            runfiles = ctx.runfiles(files = [ctx.outputs.executable]),
        ),
        RunEnvironmentInfo(env),
    ]

_ATTRS = {
    "binary": attr.label(executable = True, cfg = "target"),
    "build_args": attr.string_list(),
    "build_env": attr.string_dict(),
    "data": attr.label_list(allow_files = True, doc = "Any additional data that will be made available inside the appimage"),
    "env": attr.string_dict(doc = "Runtime environment variables. See https://bazel.build/reference/be/common-definitions#common-attributes-tests"),
    "icon": attr.label(default = "@appimagetool.png//file", allow_single_file = True),
    "_tool": attr.label(default = "//appimage/private/tool", executable = True, cfg = "exec"),
}

appimage = rule(
    implementation = _appimage_impl,
    attrs = _ATTRS,
    executable = True,
    toolchains = ["//appimage:appimage_toolchain_type"],
)

appimage_test = rule(
    implementation = _appimage_impl,
    attrs = _ATTRS,
    test = True,
    toolchains = ["//appimage:appimage_toolchain_type"],
)
