# -*- coding: utf-8 -*-
#
# Copyright 2013 whiteleaf. All rights reserved.
#

require "fileutils"
require "memoist"
require_relative "helper"
require_relative "inventory"
if Helper.engine_jruby?
  require_relative "extensions/jruby"
end

module Narou
class << self
  extend Memoist

  LOCAL_SETTING_DIR = ".narou"
  GLOBAL_SETTING_DIR = ".narousetting"
  AOZORAEPUB3_JAR_NAME = "AozoraEpub3.jar"
  AOZORAEPUB3_DIR = "AozoraEpub3"
  PRESET_DIR = "preset"
  MISC_DIR = "misc"
  EXIT_ERROR_CODE = 127

  @@is_web = false

  def get_root_dir
    root_dir = nil
    path = File.expand_path(File.dirname("."))
    drive_letter = ""
    if Helper.os_windows?
      path.gsub!(/^[a-z]:/i, "")
      drive_letter = $&
    end
    while path != ""
      if File.directory?("#{drive_letter}#{path}/#{LOCAL_SETTING_DIR}")
        root_dir = drive_letter + path
        break
      end
      path.gsub!(%r!/[^/]*$!, "")
    end
    root_dir
  end
  memoize :get_root_dir

  def get_local_setting_dir
    local_setting_dir = nil
    root_dir = get_root_dir
    if root_dir
      local_setting_dir = File.join(root_dir, LOCAL_SETTING_DIR)
    end
    local_setting_dir
  end
  memoize :get_local_setting_dir

  def get_global_setting_dir
    global_setting_dir = File.expand_path(File.join("~", GLOBAL_SETTING_DIR))
    unless File.exist?(global_setting_dir)
      FileUtils.mkdir(global_setting_dir)
    end
    global_setting_dir
  end
  memoize :get_global_setting_dir

  def get_script_dir
    File.expand_path(File.join(File.dirname(__FILE__), ".."))
  end
  memoize :get_script_dir

  def already_init?
    !!get_root_dir
  end

  def init
    return nil if already_init?
    FileUtils.mkdir(LOCAL_SETTING_DIR)
    puts LOCAL_SETTING_DIR + "/ を作成しました"
    Database.init
  end

  def alias_to_id(target)
    aliases = Inventory.load("alias", :local)
    if aliases[target]
      return aliases[target]
    end
    target
  end

  def novel_frozen?(target)
    id = Downloader.get_id_by_target(target) or return false
    Inventory.load("freeze", :local).include?(id)
  end

  def get_preset_dir
    File.expand_path(File.join(get_script_dir, PRESET_DIR))
  end
  memoize :get_preset_dir

  def create_aozoraepub3_jar_path(*paths)
    File.expand_path(File.join(*paths, AOZORAEPUB3_JAR_NAME))
  end

  def aozoraepub3_directory?(path)
    File.exist?(create_aozoraepub3_jar_path(path))
  end

  #
  # AozoraEpub3 の実行ファイル(.jar)のフルパス取得
  # 検索順序
  # 1. グローバルセッティング (global_setting aozoraepub3dir)
  # 2. 小説保存ディレクトリ(Narou.get_root_dir) 直下の AozoraEpub3
  # 3. スクリプト保存ディレクトリ(Narou.get_script_dir) 直下の AozoraEpub3
  #
  def get_aozoraepub3_path
    global_setting_aozora_path = Inventory.load("global_setting", :global)["aozoraepub3dir"]
    if global_setting_aozora_path
      aozora_jar_path = create_aozoraepub3_jar_path(global_setting_aozora_path)
      if File.exist?(aozora_jar_path)
        return aozora_jar_path
      end
    end
    [Narou.get_root_dir, Narou.get_script_dir].each do |dir|
      aozora_jar_path = create_aozoraepub3_jar_path(dir, AOZORAEPUB3_DIR)
      if File.exist?(aozora_jar_path)
        return aozora_jar_path
      end
    end
    nil
  end
  memoize :get_aozoraepub3_path

  def create_novel_filename(novel_data, ext = "")
    author, title = %w(author title).map { |k|
      Helper.replace_filename_special_chars(novel_data[k], true)
    }
    "[#{author}] #{title}#{ext}"
  end

  def get_mobi_path(target)
    get_ebook_file_path(target, ".mobi")
  end

  def get_ebook_file_path(target, ext)
    data = Downloader.get_data_by_target(target)
    return nil unless data
    dir = Downloader.get_novel_data_dir_by_target(target)
    File.join(dir, create_novel_filename(data, ext))
  end

  def get_misc_dir
    File.join(get_root_dir, MISC_DIR)
  end

  require_relative "device"

  def get_device(device_name = nil)
    device_name = Inventory.load("local_setting", :local)["device"] unless device_name
    if device_name && Device.exists?(device_name)
      return Device.create(device_name)
    end
    nil
  end

  def web=(bool)
    @@is_web = bool
  end

  def web?
    @@is_web
  end
end
end
