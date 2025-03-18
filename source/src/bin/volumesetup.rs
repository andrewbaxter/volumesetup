use {
    aargvark::{
        traits_impls::AargvarkJson,
        vark,
        Aargvark,
    },
    blockdev::lsblk,
    loga::{
        ea,
        fatal,
        DebugDisplay,
        Log,
        ResultContext,
    },
    path_absolutize::Absolutize,
    std::{
        fs::create_dir_all,
        path::PathBuf,
    },
    volumesetup::config::{
        self,
        Config,
    },
    volumesetuplib::blockdev::find_unused,
};

mod volumesetuplib;

use volumesetuplib::*;

#[derive(Aargvark)]
struct RunCommand {
    config: AargvarkJson<Config>,
    validate: Option<()>,
}

#[derive(Aargvark)]
enum Command {
    Run(RunCommand),
    ListCandidates,
}

#[derive(Aargvark)]
struct Args {
    debug: Option<()>,
    command: Command,
}

fn main1() -> Result<(), loga::Error> {
    let args = vark::<Args>();
    let log = Log::new_root(if args.debug.is_some() {
        loga::DEBUG
    } else {
        loga::INFO
    });
    match args.command {
        Command::Run(args) => {
            if args.validate.is_some() {
                return Ok(());
            }
            let config = args.config.value;
            let mount_path =
                config
                    .mountpoint
                    .clone()
                    .unwrap_or_else(|| PathBuf::from("/mnt/persistent"))
                    .absolutize()
                    .context("Couldn't make mountpoint absolute")?
                    .into_owned();
            let blocks = lsblk()?;
            for block in &blocks {
                for mount in &block.mountpoints {
                    let Some(mp) = mount else {
                        continue;
                    };
                    if mp.as_str() == mount_path.to_string_lossy().as_ref() {
                        log.log(loga::INFO, "Already mounted, doing nothing.");
                        return Ok(());
                    }
                }
            }
            match config.fs.as_ref().unwrap_or(&config::FilesystemMode::Ext4 {}) {
                config::FilesystemMode::Ext4 {} => fs_ext4::main(&log, blocks, &config, &mount_path)?,
                config::FilesystemMode::Bcachefs {} => fs_bcachefs::main(&log, blocks, &config, &mount_path)?,
            }

            // Ensure subdirectories in mountpoint
            for path in config.ensure_dirs.unwrap_or_default() {
                create_dir_all(
                    &mount_path.join(&path),
                ).stack_context_with(
                    &log,
                    "Failed to create mount point subidr",
                    ea!(subdir = path.to_string_lossy()),
                )?;
            }
        },
        Command::ListCandidates => {
            let blocks = lsblk()?;
            let candidates = find_unused(blocks)?;
            println!("{}", candidates.into_iter().map(|c| c.path.dbg_str()).collect::<Vec<_>>().join("\n"));
        },
    }
    return Ok(());
}

fn main() {
    match main1() {
        Ok(_) => { },
        Err(e) => {
            fatal(e);
        },
    }
}
